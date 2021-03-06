package main

import (
	"errors"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/rs/zerolog"
)

// Version executable version
const Version = "0.0.3"

var log = zerolog.New(os.Stdout).With().Str("version", Version).Timestamp().Logger()

// MyEvent is the input object
type MyEvent struct {
	Name string `json:"What is your name?"`
	Age  int    `json:"How old are you?"`
}

// MyResponse is the lambda output response
type MyResponse struct {
	Message string `json:"Answer:"`
}

// HandleLambdaEvent Lambda entry point
func HandleLambdaEvent(event MyEvent) (MyResponse, error) {
	log.Info().Msgf("Starting")
	if event.Name == "" {
		return MyResponse{Message: fmt.Sprintf("No name provided")}, errors.New("No name provided")
	}
	return MyResponse{Message: fmt.Sprintf("%s is %d years old!", event.Name, event.Age)}, nil
}

func main() {
	lambda.Start(HandleLambdaEvent)
}
