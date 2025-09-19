// --- Topology Builder Duties ---

// 1. Receive Build Command
//    - Accept `num_nodes`, `topology_type`, `algorithm_type`, and `main_pid` as input.

// 2. Route the Command
//    - Use a `case` statement on the `topology_type` string:
//      - If "line", call the `create` function in the `line.gleam` file.
//      - If "3d", call the `create` function in the `grid_3d.gleam` file.
//      - (and so on for the other topologies)
//    - Pass all the arguments along to the chosen function.

// 3. Return the Result
//    - Return the list of `actor_subjects` that was given back by the specific
//      topology file.