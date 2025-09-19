import gleam/otp/actor
import gossip_protocol/topology/full_network
import gossip_protocol/topology/imperfect_3D
import gossip_protocol/topology/line
import gossip_protocol/topology/three_D
import algo/gossip_algo
import algo/push_sum

pub fn build(
  num_nodes: Int,
  topology: String,
  algorithm: String,
  main_pid: actor.Pid,

) -> List(actor.Subject) {
  case topology {
    "3D" -> three_D.build(num_nodes, algorithm, main_pid)
    "imp3D" ->
      imperfect_3D.build(num_nodes, algorithm, main_pid)
    _ -> Nil
  }

  list_of_subjects = case algorithm {
    "gossip" -> gossip_algo.build(num_nodes,toplology, algorithm, main_pid)
    "push-sum" -> push_sum.build(num_nodes,topology, algorithm, main_pid)
    _ -> Nil
  }

  list_of_subjects
}
