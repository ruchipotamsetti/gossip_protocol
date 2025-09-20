import gleam/list
import gleam/otp/actor
import gossip_protocol/algo/gossip_algo
import gossip_protocol/algo/push_sum
import gossip_protocol/gossip_protocol.{MainMessage}
import gossip_protocol/topology/full_network
import gossip_protocol/topology/imperfect_3D
import gossip_protocol/topology/line
import gossip_protocol/topology/three_D

pub type NodeSubject {
  Gossip(gossip_algo.NodeSubject)
  PushSum(push_sum.NodeSubject)
}

pub fn build(
  num_nodes: Int,
  topology: String,
  algorithm: String,
  main_subject: actor.Subject(MainMessage),
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
