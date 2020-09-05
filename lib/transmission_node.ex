defmodule TransmissionNode do

	use GenServer

	def start_link(node_id) do
			name = {:via, Registry, {Registry.ViaTest, node_id}}
			GenServer.start_link(__MODULE__, node_id,  name: name )
	end

  def init(node_id) do
		{:ok, init_node_properties(node_id)}
  end

	def init_node_properties(node_id) do
	  x=Enum.map(0..15, fn a-> {a, nil}  end) |> Enum.into(%{})
	 	routing_table = Enum.map(0..8, fn a-> {a, x}  end) |> Enum.into(%{})
		node_properties = %{:node_id => node_id, :back_pointers => [], :routing_table => routing_table}
		node_properties
	end

	def get_node_pid(node_id) do
		case Registry.lookup(Registry.ViaTest, node_id) do
      [] -> nil
      [{pid, _value}] -> pid
    end
	end

	def get_routing_table(node_id) do
		pid = get_node_pid(node_id)
		GenServer.call(pid, {:get_routing_table}, 3000000)
	end

	def initialise_routing_table(node_id) do
		pid = get_node_pid(node_id)
		GenServer.cast(pid, {:initialise_routing_table})
	end

	def initialise_routing_table_from_nodes(node_id, max_matched_nodes) do
		pid = get_node_pid(node_id)
		GenServer.call(pid, {:initialise_routing_table_from_nodes, max_matched_nodes}, 3000000)
	end


	def handle_call({:get_routing_table}, _from, state) do
		{:reply, state |> Map.get(:routing_table), state}
	end

	def handle_call({:initialise_routing_table_from_nodes, max_matched_nodes}, _from, state) do
		node_id = state |> Map.get(:node_id)
		nodes_list = Live_Nodes.value
		routing_table = state |> Map.get(:routing_table)
		no_matched_levels	 = get_no_prefix_matches(Enum.at(max_matched_nodes, 0), node_id)

		routing_tables = max_matched_nodes |> Enum.map(fn x -> get_routing_table(x) end)
		table_level_slot_relation = for table <- routing_tables, x <- 0..no_matched_levels, y <- 0..15,  do: [table, x, y]

		routing_table = table_level_slot_relation |>
					Enum.reduce(routing_table, fn [table, level, slot_no], routing_table ->  put_in(routing_table,[level, slot_no],
										table[level][slot_no]) end)


# see if you need to change here
		level_slot_relation = for x <- (no_matched_levels)..8, y <- 0..15, do: [x, y]
		# routing_table = state |> Map.get(:routing_table)
		routing_table = level_slot_relation |>
					Enum.reduce(routing_table, fn [level, slot_no], routing_table ->  put_in(routing_table,[level, slot_no],
										get_neighbour(level, Integer.to_string(slot_no, 16), node_id, nodes_list)) end)


		new_state = state |> Map.put(:routing_table, routing_table)

		{:reply,max_matched_nodes , new_state}
	end


	def handle_cast({:initialise_routing_table}, state) do
		node_id = state |> Map.get(:node_id)
		nodes_list = Live_Nodes.value

		level_slot_relation = for x <- 0..8, y <- 0..15, do: [x, y]
		routing_table = state |> Map.get(:routing_table)
		routing_table = level_slot_relation |>
					Enum.reduce(routing_table, fn [level, slot_no], routing_table ->  put_in(routing_table,[level, slot_no],
										get_neighbour(level, Integer.to_string(slot_no, 16), node_id, nodes_list)) end)
		new_state = state |> Map.put(:routing_table, routing_table)

		{:noreply, new_state}
	end


	def get_neighbour(level, slot_no, node_id, nodes_list) do
		nodes_list
		# |>  Enum.filter(fn x ->x != node_id end)
		 						|> 	Enum.filter(fn x-> String.slice(x,0,level)==String.slice(node_id,0,level) end)
								# |>	Enum.filter(fn x-> String.slice(x,level,1)!=String.slice(node_id, level, 1) end)
								|>	Enum.filter(fn x-> String.slice(x, level, 1)== to_string(slot_no) end)
								|>	Enum.sort()
								|>	Enum.at(0)
  end


	def num_hops(num_hops_till_now, current_node_id, dest_node_id) do
				pid = get_node_pid(current_node_id)
				GenServer.cast(pid, {:get_num_hops, num_hops_till_now, dest_node_id})
	end

	def handle_cast({:get_num_hops, num_hops_till_now, dest_node_id}, state) do
		routing_table = state |> Map.get(:routing_table)
		current_node_id = state |> Map.get(:node_id)
		# IO.puts("current node id #{current_node_id}")

		if current_node_id==dest_node_id do
			Num_Hops_Max.new_num_hops(num_hops_till_now)
			Manager.add_message_received()
		else
			next_node = get_next_jump(current_node_id, dest_node_id, routing_table)
			GenServer.cast(get_node_pid(next_node),
							{:get_num_hops, 1+num_hops_till_now, dest_node_id})
		end
		{:noreply, state}
	end

	def get_surrogate_root(current_node_id, dest_node_id) do
				pid = get_node_pid(current_node_id)
				GenServer.call(pid, {:get_surrogate_root, dest_node_id})
	end


	def handle_call({:get_surrogate_root, dest_node_id}, _from, state) do
		routing_table = state |> Map.get(:routing_table)
		current_node_id = state |> Map.get(:node_id)
		# IO.puts("current node id #{current_node_id}")
		no_current_matching_prefixes = get_no_prefix_matches(current_node_id, dest_node_id)
		result = cond do
							 current_node_id == dest_node_id  -> dest_node_id
							 true->
								 next_node = get_next_jump(current_node_id, dest_node_id, routing_table)
								 # IO.puts("3")
								 # IO.puts("next node id #{next_node}   dest_node_id #{dest_node_id}")
								 # no_next_matching_prefixes = get_no_prefix_matches(next_node, dest_node_id)
								 # IO.puts("4")
								 cond do
									 	next_node == nil -> current_node_id
										get_no_prefix_matches(next_node, dest_node_id) > no_current_matching_prefixes ->
													get_surrogate_root(next_node, dest_node_id)
										true -> next_node
								 end
						end
			{:reply, result, state}

	end



	def get_next_jump(current_node_id, dest_node_id, routing_table) do
 		no_prefix_matched = get_no_prefix_matches(current_node_id, dest_node_id)
		next_level = routing_table |> Map.get(no_prefix_matched);
		slot_id = String.slice(dest_node_id, no_prefix_matched, 1)
		{slot_id,""} = slot_id |> Integer.parse(16)
		next_slot_list = 0..15 |> Enum.map(fn x -> rem(x + slot_id, 16) end)
		# IO.puts("1")
		next_jump = check_first_occurence(next_slot_list, next_level)
		# IO.puts("2")
		next_jump
	end

	def	check_first_occurence([head|tail], next_level) do
		next_possible_node = Map.get(next_level, head)
		case next_possible_node do
			nil -> check_first_occurence(tail, next_level)
			_ 	-> next_possible_node
		end
	end

	def	check_first_occurence([], next_level) do
		nil
	end

	def get_no_prefix_matches(node_id_1, node_id_2) do
		get_no_prefix_matched(String.codepoints(node_id_1), String.codepoints(node_id_2))
	end

	def get_no_prefix_matched([prefix1|tail1], [prefix2|tail2]) do
		cond  do
			prefix1==prefix2 -> 1 + get_no_prefix_matched(tail1, tail2)
			true 	-> 0
		end
	end

	def get_no_prefix_matched([], []) do
		0
	end

	def insert_node(new_node_id) do
		# surrogate_node = get_surrogate_root(current_node_id, new_node_id)
			TransmissionNode.start_link(new_node_id)
			Live_Nodes.add_node(new_node_id)
			max_matched_nodes = find_max_prefix_match_nodes(new_node_id, Live_Nodes.value, 0)
			insert_into_routing_tables(max_matched_nodes, new_node_id)
			TransmissionNode.initialise_routing_table_from_nodes(new_node_id, max_matched_nodes)

	end

	def insert_into_routing_tables(nodes_list, new_node) do
		nodes_list |> Enum.map(fn node_id -> get_node_pid(node_id) end)
							 |> Enum.each(fn pid ->	GenServer.cast(pid, {:add_to_routing_table, new_node} )end)
	end

	def handle_cast({:add_to_routing_table, new_node_id}, state) do
		routing_table = state |> Map.get(:routing_table)
		current_node_id = state |> Map.get(:node_id)
		no_of_prefix_matches = get_no_prefix_matches(current_node_id, new_node_id)
		{slot_no, ""} = String.slice(new_node_id, no_of_prefix_matches, 1) |> Integer.parse(16)
		routing_table = put_in(routing_table,[no_of_prefix_matches, slot_no], new_node_id)
		new_state = state |> Map.put(:routing_table, routing_table)
		{:noreply, new_state}
	end


	def find_max_prefix_match_nodes(current_node, nodes_list, no_of_matches_till_now) do
		new_matched_nodes = nodes_list
												|> Enum.filter(fn x -> x != current_node end)
												|> Enum.filter(fn node_id->
													String.slice(node_id, no_of_matches_till_now, 1)== String.slice(current_node, no_of_matches_till_now, 1) end )
		cond do
			Enum.empty?(new_matched_nodes) -> nodes_list
			true-> find_max_prefix_match_nodes(current_node, new_matched_nodes, 1 + no_of_matches_till_now)
		end
	end

	# def send_message_periodically(source, no_of_msgs) do
	# 	1..no_of_msgs |> Enum.each(fn x-> send_random_message(source) end)
	# end

	def send_random_message(source) do
		pid = get_node_pid(source)
		dest_node_id = getRandomNode(Live_Nodes.value, source)
		GenServer.cast(pid, {:send_random_message, dest_node_id})
	end

	def handle_cast({:send_random_message, dest_node_id}, state) do
		GenServer.cast(self(), {:get_num_hops, 0, dest_node_id})
		# :timer.sleep(1000)
		{:noreply, state}
	end


	# def handle_info(:send_message, state) do
	# 		current_node_id = Map.get(state, :node_id)
	# 		dest_node_id = getRandomNode(Live_Nodes.value, current_node_id)
	#     GenServer.cast(self(), {:get_num_hops, 0, dest_node_id})
	#     {:noreply, state}
	# end

	def getRandomNode(nodes_list, current_node_id) do
		random_id = Enum.random(Live_Nodes.value)
		cond do
			current_node_id == random_id -> getRandomNode(nodes_list, current_node_id)
			true -> random_id
		end

	end

	def start_all_messages() do
		Live_Nodes.value |> Enum.each(fn node -> send_random_message(node) end)
		:timer.sleep(1000)
	end





end
