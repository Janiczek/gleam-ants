# gleam-ants

A reimplementation of the ants colony simulation [originally written by Rich Hickey](https://gist.github.com/michiakig/1093917).

Basically just a toy project for me to try and learn Gleam on.

The main logic is in Gleam:

* HTTP server running on :3000
  * Endpoint `GET /` returning a JSON of the current simulation state
* One actor for the board
  * Pheromones evaporate every 1s
* One actor per each ant living on the board (49 ants in total)
  * Running every 40ms

The rendering is in Elm:

* A request to `GET /` is made every 1s
* Otherwise logic-less, just decoding the JSON and showing the result

## Run

```sh
# Start the web server locally
gleam run

# Send a request to the server
curl localhost:3000

# Run the Elm app
elm reactor
open localhost:8000/src/Main.elm
```

## TODO

- [ ] Make the Elli HTTP server return the Elm app on `GET /index.html`? This will likely need me to either hack on gleam_elli or stop using it and instead run Elli with [`elli_static`](https://github.com/elli-lib/elli_static) manually...
