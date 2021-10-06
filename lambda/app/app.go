// Package app provides the underlying functionality for the grace-ansible-lambda
package app

import (
	"fmt"
	"strings"
	"sync"

	"github.com/GSA/ciss-utils/aws/sm"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/client"
	"github.com/aws/aws-sdk-go/aws/credentials/stscreds"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/kms"
	"github.com/aws/aws-sdk-go/service/organizations"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/aws/aws-sdk-go/service/sts"
	env "github.com/caarlos0/env/v6"
)

// Config holds all variables read from the ENV
type Config struct {
	Region       string `env:"REGION" envDefault:"us-east-1"`
	Prefix       string `env:"PREFIX" envDefault:"g-"`
	OrgAccountID string `env:"ORG_ACCOUNT_ID"`
	OrgRoleName  string `env:"ORG_ROLE_NAME"`
	OrgUnit      string `env:"ORG_UNIT_NAME"`
	RoleName     string `env:"ROLE_NAME"`
	KmsKeyAlias  string `env:"KMS_KEY_ALIAS"`
}


// App is a wrapper for running Lambda
type App struct {
	cfg       *Config
	sess      *session.Session
	secrets   []sm.Secret
	accounts  []string
	accountID string
	ouID      string
}

// New creates a new App
func New() (*App, error) {
	cfg := Config{}
	a := &App{
		cfg: &cfg,
	}
	err := env.Parse(&cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to parse ENV: %v", err)
	}
	return a, nil
}

// Run executes the lambda functionality
func (a *App) Run() error {
	var err error
	a.sess, err = session.NewSession(&aws.Config{Region: aws.String(a.cfg.Region)})
	if err != nil {
		return fmt.Errorf("error connecting to AWS: %v", err)
	}

	fmt.Printf("getting current account ID: %s", a.cfg.OrgUnit)
	err = a.getAccountID()
	if err != nil {
		return err
	}

	fmt.Printf("gathering source secrets")
	a.secrets, err = getSecrets(a.sess, filterSecretByPrefix(a.cfg.Prefix))
	if err != nil {
		return fmt.Errorf("failed to get source secrets: %v", err)
	}

	// Assume role into Payer
	// Enumerate accounts under OU
	fmt.Printf("gathering account IDs from organizational unit: %s", a.cfg.OrgUnit)
	err = a.getAccountList()
	if err != nil {
		return err
	}

	var wg sync.WaitGroup
	for _, account := range a.accounts {
		account := account // make a copy of account ID to prevent mutation
		wg.Add(1)
		go func() {
			defer wg.Done()
			fmt.Printf("synchronizing secrets for account: %s", account)
			err := a.syncSecrets(account)
			if err != nil {
				fmt.Printf("failed to synchronization all secrets for account: %s -> %v", account, err)
				return
			}
			fmt.Printf("synchronization complete for account: %s", account)
		}()
	}
	wg.Wait()
	fmt.Printf("completed secret synchronization")

	return nil
}

func (a *App) syncSecrets(accountID string) error {
	creds := stscreds.NewCredentials(a.sess, "arn:aws:iam::"+accountID+":role/"+a.cfg.RoleName)
	sess, err := session.NewSession(&aws.Config{
		Region:      aws.String(a.cfg.Region),
		Credentials: creds,
	})
	if err != nil {
		return fmt.Errorf("failed to assume role for account: %s -> %v", accountID, err)
	}

	keyID, err := a.getKeyIDFromAlias(sess, accountID)
	if err != nil {
		return err
	}

	secrets, err := getSecrets(sess, filterSecretByKeyID(keyID))
	if err != nil {
		return fmt.Errorf("failed to get secrets for account: %s -> %v", accountID, err)
	}

	svc := secretsmanager.New(sess)
	for _, src := range a.secrets {
		found := false
		for _, dst := range secrets {
			if !strings.EqualFold(src.Name, a.cfg.Prefix+dst.Name) {
				continue
			}
			found = true
			if src.Value == dst.Value {
				fmt.Printf("no update required for secret %s in account %s\n", dst.Name, accountID)
				continue
			}
			fmt.Printf("updating secret %s for account %s\n", dst.Name, accountID)
			out, err := svc.UpdateSecret(&secretsmanager.UpdateSecretInput{
				SecretId:     aws.String(src.ID),
				SecretString: aws.String(src.Value),
				KmsKeyId:     aws.String(keyID),
			})
			if err != nil {
				return fmt.Errorf("failed to update secret: %s -> %v", dst.Name, err)
			}
			fmt.Printf("updated secret %s for account %s new version is %s\n",
				dst.Name, accountID, aws.StringValue(out.VersionId))
		}
		if !found {
			name := src.Name[len(a.cfg.Prefix):]
			_, err := svc.CreateSecret(&secretsmanager.CreateSecretInput{
				Name:         aws.String(name),
				SecretString: aws.String(src.Value),
				KmsKeyId:     aws.String(keyID),
			})
			if err != nil {
				return fmt.Errorf("failed to create secret: %s -> %v", name, err)
			}
			fmt.Printf("created secret %s for account %s\n",
				name, accountID)
		}
	}

	return nil
}

func (a *App) getKeyIDFromAlias(cfg client.ConfigProvider, accountID string) (string, error) {
	keyID := ""
	svc := kms.New(cfg)
	err := svc.ListAliasesPages(&kms.ListAliasesInput{}, func(page *kms.ListAliasesOutput, lastPage bool) bool {
		for _, alias := range page.Aliases {
			if !strings.EqualFold(a.cfg.KmsKeyAlias, aws.StringValue(alias.AliasName)) {
				continue
			}
			keyID = aws.StringValue(alias.TargetKeyId)
			return false
		}
		return !lastPage
	})
	if err != nil {
		return keyID, fmt.Errorf("failed to list key aliases for account: %s -> %v", accountID, err)
	}

	if len(keyID) == 0 {
		return keyID, fmt.Errorf("failed to locate a matching alias for account: %s -> %s", accountID, a.cfg.KmsKeyAlias)
	}

	return keyID, nil
}

func (a *App) getAccountID() error {
	svc := sts.New(a.sess)

	out, err := svc.GetCallerIdentity(&sts.GetCallerIdentityInput{})
	if err != nil {
		return fmt.Errorf("failed to get current account information: %v", err)
	}

	a.accountID = aws.StringValue(out.Account)
	return nil
}

type secretMatcher func(*secretsmanager.SecretListEntry) bool

func filterSecretByPrefix(prefix string) secretMatcher {
	return func(s *secretsmanager.SecretListEntry) bool {
		return strings.HasPrefix(aws.StringValue(s.Name), prefix)
	}
}

func filterSecretByKeyID(keyID string) secretMatcher {
	return func(s *secretsmanager.SecretListEntry) bool {
		return strings.EqualFold(aws.StringValue(s.KmsKeyId), keyID)
	}
}

func getSecrets(cfg client.ConfigProvider, matcher secretMatcher) ([]sm.Secret, error) {
	svc := secretsmanager.New(cfg)

	var secrets []sm.Secret
	err := svc.ListSecretsPages(&secretsmanager.ListSecretsInput{},
		func(page *secretsmanager.ListSecretsOutput, lastPage bool) bool {
			for _, s := range page.SecretList {
				if !matcher(s) {
					continue
				}
				secrets = append(secrets, sm.Secret{
					ID:    aws.StringValue(s.ARN),
					Name:  aws.StringValue(s.Name),
					Value: "",
				})
			}
			return !lastPage
		})
	if err != nil {
		return nil, fmt.Errorf("failed to list secrets: %v", err)
	}
	for _, s := range secrets {
		out, err := svc.GetSecretValue(&secretsmanager.GetSecretValueInput{
			SecretId: aws.String(s.ID),
		})
		if err != nil {
			return nil, fmt.Errorf("failed to get secret value for: %s -> %v", s.Name, err)
		}
		s.Value = aws.StringValue(out.SecretString)
	}

	return secrets, nil
}

func (a *App) getAccountList() error {
	creds := stscreds.NewCredentials(a.sess, "arn:aws:iam::"+a.cfg.OrgAccountID+":role/"+a.cfg.OrgRoleName)
	sess, err := session.NewSession(&aws.Config{
		Region:      aws.String(a.cfg.Region),
		Credentials: creds,
	})
	if err != nil {
		return fmt.Errorf("error connecting to Master Payer: %v", err)
	}
	svc := organizations.New(sess)

	roots, err := svc.ListRoots(&organizations.ListRootsInput{})
	if err != nil {
		return fmt.Errorf("failed to list roots for organization: %v", err)
	}

	err = svc.ListOrganizationalUnitsForParentPages(&organizations.ListOrganizationalUnitsForParentInput{
		ParentId: roots.Roots[0].Id, // there should only ever be one root
	}, func(page *organizations.ListOrganizationalUnitsForParentOutput, lastPage bool) bool {
		for _, ou := range page.OrganizationalUnits {
			if strings.EqualFold(aws.StringValue(ou.Name), a.cfg.OrgUnit) {
				a.ouID = aws.StringValue(ou.Id)
				return false
			}
		}
		return !lastPage
	})
	if err != nil {
		return fmt.Errorf("failed to list OUs for root: %s -> %v", aws.StringValue(roots.Roots[0].Id), err)
	}

	if len(a.ouID) == 0 {
		return fmt.Errorf("failed to locate organizational unit with name: %s", a.cfg.OrgUnit)
	}

	err = svc.ListAccountsForParentPages(&organizations.ListAccountsForParentInput{
		ParentId: aws.String(a.ouID),
	}, func(page *organizations.ListAccountsForParentOutput, lastPage bool) bool {
		for _, account := range page.Accounts {
			a.accounts = append(a.accounts, aws.StringValue(account.Id))
		}
		return !lastPage
	})
	if err != nil {
		return fmt.Errorf("failed to list accounts for parent: %s -> %v", a.ouID, err)
	}
	return nil
}
