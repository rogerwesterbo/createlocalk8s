package cmd

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/spf13/cobra"
)

var randomCmd = &cobra.Command{
	Use:   "dadjoke",
	Short: "Get a random dad joke",
	Long:  `This command fetches a random dad joke from the icanhazdadjoke api`,
	Run: func(cmd *cobra.Command, args []string) {
		getRandomJoke()
	},
}

func init() {
	rootCmd.AddCommand(randomCmd)
}

type Joke struct {
	ID     string `json:"id"`
	Joke   string `json:"joke"`
	Status int    `json:"status"`
}

func getRandomJoke() {
	url := "https://icanhazdadjoke.com/"
	responseBytes := getJokeData(url)
	joke := Joke{}

	if err := json.Unmarshal(responseBytes, &joke); err != nil {
		_, _ = fmt.Printf("Could not unmarshal reponseBytes. %v", err)
	}

	fmt.Println(joke.Joke)
}

func getJokeData(baseAPI string) []byte {
	request, err := http.NewRequest(
		http.MethodGet, //method
		baseAPI,        //url
		nil,            //body
	)

	if err != nil {
		fmt.Printf("Could not request a dadjoke. %v", err)
		cobra.CheckErr(err)
	}

	request.Header.Add("Accept", "application/json")
	request.Header.Add("User-Agent", "Dadjoke CLI (https://github.com/example/dadjoke)")

	response, err := http.DefaultClient.Do(request)
	if err != nil {
		fmt.Printf("Could not request a dadjoke. %v", err)
		cobra.CheckErr(err)
	}

	responseBytes, err := io.ReadAll(response.Body)
	if err != nil {
		fmt.Printf("Could not read response body. %v", err)
		cobra.CheckErr(err)
	}

	return responseBytes
}
