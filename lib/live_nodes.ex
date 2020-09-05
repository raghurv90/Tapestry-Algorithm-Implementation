defmodule Live_Nodes do

  use Agent

  def start_link(nodes_list) do
    Agent.start_link(fn -> nodes_list end, name: :live_nodes)
  end

  def value do
    Agent.get(:live_nodes, & &1, 300000)
  end

  def add_node(node_id) do
    Agent.update(:live_nodes, & &1 ++[node_id], 300000)
  end

end
