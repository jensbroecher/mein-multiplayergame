extends Node

const BROADCAST_PORT = 10568
const LISTEN_PORT = 10568
const BROADCAST_INTERVAL = 1.0

var broadcast_peer: PacketPeerUDP
var listen_peer: PacketPeerUDP
var broadcast_timer: Timer

var is_broadcasting = false
var is_listening = false

var server_name = "Host"
var server_port = NetworkManager.DEFAULT_PORT

# Found servers are stored here. Key: IP string, Value: { "name": String, "port": int, "last_seen": float }
var discovered_servers = {}
signal server_found(ip: String, info: Dictionary)
signal server_lost(ip: String)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	broadcast_timer = Timer.new()
	add_child(broadcast_timer)
	broadcast_timer.wait_time = BROADCAST_INTERVAL
	broadcast_timer.timeout.connect(_on_broadcast_timer_timeout)

func start_broadcasting(host_name: String, port: int):
	server_name = host_name
	server_port = port
	
	broadcast_peer = PacketPeerUDP.new()
	broadcast_peer.set_broadcast_enabled(true)
	# Target IP for broadcast is 255.255.255.255
	broadcast_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)
	
	is_broadcasting = true
	broadcast_timer.start()
	print("LANDiscovery: Started broadcasting on port ", BROADCAST_PORT)

func stop_broadcasting():
	is_broadcasting = false
	broadcast_timer.stop()
	if broadcast_peer:
		broadcast_peer.close()
	print("LANDiscovery: Stopped broadcasting")

func start_listening():
	listen_peer = PacketPeerUDP.new()
	var err = listen_peer.bind(LISTEN_PORT)
	if err == OK:
		is_listening = true
		print("LANDiscovery: Started listening on port ", LISTEN_PORT)
	else:
		printerr("LANDiscovery: Failed to bind listen port ", LISTEN_PORT, " Error: ", err)

func stop_listening():
	is_listening = false
	if listen_peer:
		listen_peer.close()
	discovered_servers.clear()
	print("LANDiscovery: Stopped listening")

func stop_all():
	stop_broadcasting()
	stop_listening()

func _on_broadcast_timer_timeout():
	if is_broadcasting and broadcast_peer:
		var packet = {
			"type": "lan_discovery",
			"name": server_name,
			"port": server_port
		}
		var data = JSON.stringify(packet).to_utf8_buffer()
		var err = broadcast_peer.put_packet(data)
		if err != OK:
			printerr("LANDiscovery: Failed to broadcast packet")

func _process(_delta):
	# Timeout old servers
	if is_listening:
		var now = Time.get_ticks_msec() / 1000.0
		var ips_to_remove = []
		for ip in discovered_servers.keys():
			if now - discovered_servers[ip].last_seen > 3.0: # 3 seconds timeout
				ips_to_remove.append(ip)
		
		for ip in ips_to_remove:
			discovered_servers.erase(ip)
			server_lost.emit(ip)
	
	if is_listening and listen_peer and listen_peer.get_available_packet_count() > 0:
		var packet = listen_peer.get_packet()
		var ip = listen_peer.get_packet_ip()
		var port = listen_peer.get_packet_port()
		
		# Ignore packets from ourselves if hosting and listening simultaneously?
		# Actually, it's fine. We just check if IP is not our own, or we don't care.
		for local_ip in IP.get_local_addresses():
			if ip == local_ip:
				return # Skip our own broadcast
		
		if packet.size() > 0:
			var packet_string = packet.get_string_from_utf8()
			var json = JSON.new()
			var error = json.parse(packet_string)
			if error == OK:
				var data = json.get_data()
				if typeof(data) == TYPE_DICTIONARY and data.get("type") == "lan_discovery":
					var s_name = data.get("name", "Unknown")
					var s_port = data.get("port", port)
					var now = Time.get_ticks_msec() / 1000.0
					
					var was_new = not discovered_servers.has(ip)
					discovered_servers[ip] = {
						"name": s_name,
						"port": s_port,
						"last_seen": now
					}
					
					if was_new:
						server_found.emit(ip, discovered_servers[ip])
