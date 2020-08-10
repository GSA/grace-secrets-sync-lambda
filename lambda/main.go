package main

import (
	"github.com/GSA/grace-ansible-lambda/lambda/app"
	"github.com/aws/aws-lambda-go/lambda"
)

func main() {
	a, err := app.New()
	if err != nil {
		panic(err)
	}
	lambda.Start(a.Run)
}
