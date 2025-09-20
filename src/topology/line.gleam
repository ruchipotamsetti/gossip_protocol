// --- Specific Topology Duties (e.g., Line Topology) ---

// --- PHASE 1: SPAWN AND COLLECT ---

// 1. Initiate Spawning
//    - Loop from 1 to `num_nodes`.
//    - In each loop, spawn a new actor using the logic from `actor/node.gleam`.
//    - The `main_pid` is passed to each new actor so it knows who to talk to.

// 2. Collect Subjects
//    - After starting the spawning process, enter a new loop.
//    - Wait to receive `ActorSubjectIs` messages from the newly created actors.
//    - Store each incoming subject in a list until `num_nodes` subjects have been collected.
//    - Now you have a complete list mapping index `i` to the subject for node `i`.

// --- PHASE 2: CONFIGURE AND DISTRIBUTE ---

// 3. Calculate Neighbor Lists
//    - Loop through your list of collected subjects from index `i` = 0 to num_nodes - 1.
//    - For each subject `i`, calculate the indices of its neighbors (e.g., `i-1` and `i+1`).
//    - Look up the subjects for those neighbor indices in your collected list.

// 4. Distribute Neighbor Lists
//    - Send a `SetNeighbors` message to subject `i`, containing its list of neighbor subjects.

import gleam/list

pub fn find_neighbours(node_index: Int, num_nodes: Int) -> List(Int) {
  case node_index {
    1 -> [2]
    _ if node_index == num_nodes -> [node_index - 1]
    _ -> [node_index - 1, node_index + 1]
  }
}
