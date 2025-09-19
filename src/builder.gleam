// --- Topology Builder Duties ---

// 1. Receive Build Command
//    - Accept `num_nodes`, `topology_type`, `algorithm_type`, and `main_pid` as input.

// 2. Route the Command
//    - Use a `case` statement on the `algo type` string:
//      route to specific neighbour functions in alog/
//    - if topo is 3D or imperfect 3D , call the prebuild fucntions

// 3. Return the Result
//    - Return the list of `actor_subjects` that was given back by the specific
//      topology file to main.