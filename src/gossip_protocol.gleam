// --- Main Process Duties ---

// 1. Parse Command-Line Arguments
//    - Get num_nodes, topology_type, and algorithm_type from the input.

// 2. Start the Clock
//    - Record the system's start time for the final measurement.

// 3. Build the Network
//    - Call the `topology/builder` with the parsed arguments.
//    - The builder will do all the setup work and return a complete
//      list of `actor_subjects` for the main process to use.

// 4. Start the Protocol
//    - Pick one (or more) subjects from the returned list.
//    - Send the initial "start" message (e.g., `Gossip` or `StartPushSum`)
//      to the chosen subject(s).

// 5. Wait for Completion
//    - Enter a loop to receive messages.
//    - Keep a countdown of `actors_remaining` (e.g., starting at 99% of num_nodes).
//    - When an `ActorFinished` message is received, decrement the counter.
//    - When the counter reaches zero, exit the loop.

// 6. Stop the Clock & Report
//    - Record the system's end time.
//    - Calculate and print the total duration.