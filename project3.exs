[no_of_nodes, no_of_msgs] = Enum.map(System.argv(), fn(n) -> String.to_integer(n) end)
{:ok, _pid} = Project3.MainSupervisor.start_link(no_of_nodes)
# IO.puts "a"
Manager.start_link(self(), no_of_nodes, no_of_msgs)
# IO.puts "b"
Live_Nodes.value |> Enum.each(fn x -> TransmissionNode.initialise_routing_table(x) end)
# IO.puts "c"
Nodes_To_Be_Added.value |> Enum.each(fn x -> TransmissionNode.insert_node(x) end)
# IO.puts "d"
1..no_of_msgs |> Enum.each(fn _x-> TransmissionNode.start_all_messages() end)
# IO.puts "e"

receive do
    {:task_completed, _msg}  -> IO.puts "#{Num_Hops_Max.value}"
    _ -> IO.puts "incorrect message"
end
