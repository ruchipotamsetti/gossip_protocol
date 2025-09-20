import algo/gossip_algo
import algo/push_sum
import gleam/erlang/process
import gleam/list
import topology/full_network
import topology/imperfect_three_d
import topology/line
import topology/three_d

pub type NodeSubject {
  Gossip(gossip_algo.NodeSubject)
  PushSum(push_sum.NodeSubject)
}

pub fn build(
  num_nodes: Int,
  topology: String,
  algorithm: String,
  main_subject: process.Subject(a),
) -> List(NodeSubject) {
  case algorithm {
    "gossip" -> {
      gossip_algo.build(num_nodes, topology, main_subject)
      |> list.map(Gossip)
    }
    "push-sum" -> {
      push_sum.build(num_nodes, topology, main_subject)
      |> list.map(PushSum)
    }
    _ -> []
  }
}

pub fn kick_off(subjects: List(NodeSubject)) {
  case list.first(subjects) {
    Error(_) -> Nil
    Ok(first) ->
      case first {
        Gossip(node) -> process.send(node, gossip_algo.Gossip)
        PushSum(node) -> process.send(node, push_sum.Start)
      }
  }
}
