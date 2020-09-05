defmodule Project3.MainSupervisor do
	use Supervisor

	def start_link(no_of_nodes) do
		Supervisor.start_link(__MODULE__, no_of_nodes, restart: :transient)
	end

	def init(no_of_nodes) do
		{:ok, _} = Registry.start_link(keys: :unique, name: Registry.ViaTest)

		nodes_list = 1..3*no_of_nodes
									|> Enum.map(fn x-> to_string(x) end)
									|> Enum.map(fn x->:crypto.hash(:sha, x)
									|> Base.encode16 end)
									|> Enum.map(fn x-> String.slice(x,0,8) end)
									|> Enum.uniq()
									|> Enum.shuffle()
									# |> Enum.sort()


		# nodes_list = ["1523","1612","2261","2341","2354","2345","2346", "2442","2452","2460",
		# 						"2634","3461","3521","3536","3645", "4123","4145","4532","4546"]


		Live_Nodes.start_link(Enum.slice(nodes_list, 0, div(no_of_nodes*95,100)))
		Nodes_To_Be_Added.start_link(Enum.slice(nodes_list, div(no_of_nodes*95,100) + 2,
																	no_of_nodes - div(no_of_nodes*95,100)))
		Num_Hops_Max.start_link()

		newc =  Enum.map(Live_Nodes.value, fn node_id ->
						Supervisor.child_spec({TransmissionNode, node_id}, id: node_id,  type: :worker) end )

		Supervisor.init(newc, strategy: :one_for_one, restart: :transient)
	end

end
