// --- Actor Node Duties ---

// 1. Initialization
//    - On startup, create a unique `Subject` for myself.
//    - Send this subject to the `main_pid` in an `ActorSubjectIs` message.
//    - Set my initial state (e.g., rumor count is 0, s/w values, etc.).
//    - Start a recurring timer to send a `GossipTick` message to myself.

// 2. Message Handling (Main Loop)
//    - Wait for and react to different messages:
//      - On `SetNeighbors(subjects)`: Store the list of subjects in my state.
//      - On `Gossip` from a neighbor: Update my `rumor_heard_count`. Check if I'm finished.
//      - On `PushSum(s, w)` from a neighbor: Update my `s` and `w` values. Check if I'm finished.
//      - On `GossipTick` from myself:
//        - Pick a random neighbor subject from my list.
//        - Send it the appropriate message (`Gossip` or `PushSum(s/2, w/2)`).

// 3. Termination Logic
//    - After handling any message, check if my termination condition is met:
//      - (For gossip: `rumor_heard_count` >= 10?)
//      - (For push-sum: `s/w` ratio is stable for 3 rounds?)
//    - If the condition is met:
//      - Send one final `ActorFinished` message to the `main_pid`.
//      - Stop my own process.