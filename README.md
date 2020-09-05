# Tapestry-Algorithm-Implementation

The goal of this project is to implement in Elixir using the actor model the Tapestry Algorithm and a simple object access service to prove its usefulness.

Tapestry, a peer-to-peer overlay routing infrastructure offering efficient, scalable, location-independent routing of messages directly to nearby copies of an object or service using only localized resources. Tapestry supports a generic decentralized object location and routing applications program- ming interface using a self-repairing, soft-state-based routing layer. This paper presents the Tapestry architecture, algorithms, and implementation. It explores the behavior of a Tapestry deployment on PlanetLab, a global testbed of approximately 100 machines. Experimental results show that Tapestry exhibits stable behavior and performance as an overlay, despite the instability of the underlying network layers.

Requirements
Input: The input provided (as command line to your program will be of the form:
```
mix run project3.exs numNodes numRequests
```
Where numNodes is the number of peers to be created in the peer to peer system and numRequests the number of requests each peer has to make. When all peers performed
that many requests, the program can exit. Each peer should send a request/second.

Output: Print the maximum number of hops (node connections) that must be traversed for all requests for all nodes.

Working, Observations and Result:
Random hashes are generated for the nodes required. 95% of the nodes are initialised intitially. The static tables are then created by going through all the nodes that have been initialised. The rest of the 5% nodes are then initialised dynamically. Their routing tables are initialised by joining the routing tables of those which have the maximum prefix matches. Their routing tables are also changed as required. Then each node transmits a message to a random node the required number of times. 

The implementation worked with 1000 nodes and 10 requests. It also worked woth 5000 nodes with 5 requests.
It generally took 5 hops for both the cases.
