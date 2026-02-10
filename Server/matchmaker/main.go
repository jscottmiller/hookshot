package main

import (
	"context"
	"encoding/json"
	"flag"
	"html/template"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"golang.org/x/exp/slices"
)

var addr = flag.String("addr", "0.0.0.0:80", "http service address")

var upgrader = websocket.Upgrader{} // use default options

var matchmaker Matchmaker

type Matchmaker struct {
	sync.Mutex

	AvailableServers []*Server
	ActivePlayers    []uuid.UUID
	MatchRequests    []*Player
	PlayerCount      int
}

type Server struct {
	SessionID uuid.UUID
	TicketID  uuid.UUID
	Address   string
	Port      int
	Capacity  int
	Players   []*Player

	allocations chan uuid.UUID
}

type Player struct {
	SessionID       uuid.UUID
	allocatedServer chan *AllocatedServer
}

type AllocatedServer struct {
	TicketID uuid.UUID
	Address  string
	Port     int
}

func (m *Matchmaker) registerServer(availableServer *Server) {
	log.Println("matchmaker: server available:", availableServer)

	m.Lock()
	defer m.Unlock()

	idx := slices.IndexFunc(m.AvailableServers, func(s *Server) bool { return s.SessionID == availableServer.SessionID })
	if idx >= 0 {
		availableServer.Players = m.AvailableServers[idx].Players
		m.AvailableServers[idx] = availableServer
	} else {
		m.AvailableServers = append(m.AvailableServers, availableServer)
	}
}

func (m *Matchmaker) unregisterServer(id uuid.UUID) {
	log.Println("matchmaker: unavailable server:", id)

	m.Lock()
	defer m.Unlock()

	idx := slices.IndexFunc(m.AvailableServers, func(s *Server) bool { return s.SessionID == id })
	if idx >= 0 {
		m.AvailableServers = append(m.AvailableServers[:idx], m.AvailableServers[idx+1:]...)
	}
}

func (m *Matchmaker) disconnectServer(id uuid.UUID) {
	log.Println("matchmaker: disconnecting server:", id)

	m.Lock()
	defer m.Unlock()

	idx := slices.IndexFunc(m.AvailableServers, func(s *Server) bool { return s.SessionID == id })
	if idx >= 0 {
		m.AvailableServers = append(m.AvailableServers[:idx], m.AvailableServers[idx+1:]...)
	}
}

func (m *Matchmaker) connectPlayer(id uuid.UUID) {
	log.Println("matchmaker: player connected:", id)

	m.Lock()
	defer m.Unlock()

	if !slices.Contains(m.ActivePlayers, id) {
		m.ActivePlayers = append(m.ActivePlayers, id)
	}
	m.PlayerCount++
}

func (m *Matchmaker) disconnectedPlayer(id uuid.UUID) {
	log.Println("matchmaker: player disconnected:", id)

	m.Lock()
	defer m.Unlock()

	m.PlayerCount--

	idx := slices.Index(m.ActivePlayers, id)
	if idx >= 0 {
		m.ActivePlayers = append(m.ActivePlayers[:idx], m.ActivePlayers[idx+1:]...)
	}

	for _, server := range m.AvailableServers {
		idx := slices.IndexFunc(server.Players, func(p *Player) bool { return p.SessionID == id })
		if idx >= 0 {
			server.Players = append(server.Players[:idx], server.Players[idx+1:]...)
		}
	}
}

func (m *Matchmaker) requestMatch(player *Player) {
	m.MatchRequests = append(m.MatchRequests, player)
}

func (m *Matchmaker) run(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Second)

	for {
		select {
		case <-ctx.Done():
			return

		case <-ticker.C:
			func() {
				m.Lock()
				defer m.Unlock()

				for len(m.AvailableServers) > 0 && len(m.MatchRequests) > 0 {
					server := m.AvailableServers[0]
					player := m.MatchRequests[0]

					log.Println("matchmaker: matching player to server:", player.SessionID)
					server.Players = append(server.Players, player)
					m.MatchRequests = m.MatchRequests[1:]

					for _, player := range server.Players {
						player.allocatedServer <- &AllocatedServer{
							TicketID: server.TicketID,
							Address:  server.Address,
							Port:     server.Port,
						}
					}

					if len(server.Players) == server.Capacity {
						log.Println("matchmaker: server filled:", server.SessionID)
						server.allocations <- server.TicketID
						m.AvailableServers = m.AvailableServers[1:]
					}
				}
			}()
		}
	}
}

type PingMessage struct {
	MessageType string `json:"message_type"`
}

type BaseServerMessage struct {
	MessageType string `json:"message_type"`
}

type RegisterServerMessage struct {
	MessageType string `json:"message_type"`

	Address  string `json:"address"`
	Port     int    `json:"port"`
	Capacity int    `json:"capacity"`
}

type ServerRegisteredMessage struct {
	MessageType string `json:"message_type"`

	TicketID uuid.UUID `json:"ticket_id"`
}

type ServerAllocatedMessage struct {
	MessageType string `json:"message_type"`

	TicketID uuid.UUID `json:"ticket_id"`
}

type UnregisterServerMessage struct {
	MessageType string `json:"message_type"`
}

func handleServerWebsocket(w http.ResponseWriter, r *http.Request) {
	c, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Print("upgrade:", err)
		return
	}
	defer c.Close()

	flyRegion := r.Header.Get("fly-region")
	log.Println("new server connection from:", flyRegion)

	sessionID := uuid.New()

	messages := make(chan []byte)
	done := make(chan struct{})
	go func() {
		for {
			_, message, err := c.ReadMessage()
			if err != nil {
				log.Println("disconnect:", err)
				done <- struct{}{}
				return
			} else {
				messages <- message
			}
		}
	}()

	allocated := make(chan uuid.UUID)
	pingTimer := time.NewTicker(5 * time.Second)

readLoop:
	for {
		select {
		case <-done:
			matchmaker.disconnectServer(sessionID)
			break readLoop

		case raw_message := <-messages:
			base := BaseServerMessage{}
			if err := json.Unmarshal(raw_message, &base); err != nil {
				log.Println("invalid base server message:", err)
				continue
			}
			switch base.MessageType {
			case "ping":
				// Ignored

			case "register":
				register := RegisterServerMessage{}
				if err := json.Unmarshal(raw_message, &register); err != nil {
					log.Println("invalid register server message:", err)
					continue
				}

				ticketID := uuid.New()

				matchmaker.registerServer(&Server{
					SessionID: sessionID,
					TicketID:  ticketID,
					Address:   register.Address,
					Port:      register.Port,
					Capacity:  register.Capacity,

					allocations: allocated,
				})

				if err := c.WriteJSON(ServerRegisteredMessage{
					MessageType: "server-registered",
					TicketID:    ticketID,
				}); err != nil {
					log.Println("error writing server registered message, closing connection:", err)
					c.Close()
				}

			case "unregister":
				matchmaker.unregisterServer(sessionID)

			default:
				log.Println("Unknown server message type:", base.MessageType)
			}

		case ticketID := <-allocated:
			if err := c.WriteJSON(ServerAllocatedMessage{
				MessageType: "server-allocated",
				TicketID:    ticketID,
			}); err != nil {
				log.Println("error writing server allocated message, closing connection:", err)
				c.Close()
			}

		case <-pingTimer.C:
			if err := c.WriteJSON(PingMessage{
				MessageType: "ping",
			}); err != nil {
				log.Println("error writing server ping message, closing connection:", err)
				c.Close()
			}
		}
	}
}

type BasePlayerMessage struct {
	MessageType string `json:"message_type"`
}

type StatusPlayerMessage struct {
	MessageType string `json:"message_type"`

	PlayerCount int `json:"player_count"`
}

type ServerFoundPlayerMessage struct {
	MessageType string `json:"message_type"`

	TicketID uuid.UUID `json:"ticket_id"`
	Address  string    `json:"address"`
	Port     int       `json:"port"`
}

type RequestMatchPlayerMessage struct {
	MessageType string `json:"message_type"`
}

func handlePlayerWebsocket(w http.ResponseWriter, r *http.Request) {
	c, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Print("upgrade:", err)
		return
	}
	defer c.Close()

	flyRegion := r.Header.Get("fly-region")
	log.Println("new server connection from:", flyRegion)

	sessionID := uuid.New()
	allocatedServer := make(chan *AllocatedServer)

	matchmaker.connectPlayer(sessionID)

	messages := make(chan []byte)
	done := make(chan struct{})
	go func() {
		for {
			_, message, err := c.ReadMessage()
			if err != nil {
				log.Println("player read:", err)
				done <- struct{}{}
				return
			} else {
				messages <- message
			}
		}

	}()

	if err := c.WriteJSON(StatusPlayerMessage{
		MessageType: "status",
		PlayerCount: matchmaker.PlayerCount,
	}); err != nil {
		log.Println("error writing client status message:", err)
	}

	statusTimer := time.NewTicker(5 * time.Second)
	pingTimer := time.NewTicker(5 * time.Second)

readLoop:
	for {
		select {
		case <-done:
			matchmaker.disconnectedPlayer(sessionID)
			break readLoop

		case raw_message := <-messages:
			base := BasePlayerMessage{}
			if err := json.Unmarshal(raw_message, &base); err != nil {
				log.Println("invalid base player message:", err)
				continue
			}
			switch base.MessageType {
			case "ping":
				// Ignored

			case "request-match":
				matchmaker.requestMatch(&Player{
					SessionID:       sessionID,
					allocatedServer: allocatedServer,
				})
			}

		case allocatedServer := <-allocatedServer:
			if err := c.WriteJSON(ServerFoundPlayerMessage{
				MessageType: "server-found",
				TicketID:    allocatedServer.TicketID,
				Address:     allocatedServer.Address,
				Port:        allocatedServer.Port,
			}); err != nil {
				log.Println("error writing client server found message:", err)
			}

		case <-statusTimer.C:
			if err := c.WriteJSON(StatusPlayerMessage{
				MessageType: "status",
				PlayerCount: matchmaker.PlayerCount,
			}); err != nil {
				log.Println("error writing client status message:", err)
			}

		case <-pingTimer.C:
			if err := c.WriteJSON(PingMessage{
				MessageType: "ping",
			}); err != nil {
				log.Println("error writing client ping message, closing connection:", err)
				c.Close()
			}
		}
	}
}

func stats(w http.ResponseWriter, r *http.Request) {
	statsTemplate.Execute(w, &matchmaker)
}

func main() {
	flag.Parse()
	log.SetFlags(0)
	http.HandleFunc("/client", handlePlayerWebsocket)
	http.HandleFunc("/server", handleServerWebsocket)
	http.HandleFunc("/stats", stats)

	ctx := context.Background()
	matchmaker = Matchmaker{}

	go matchmaker.run(ctx)

	err := http.ListenAndServe(*addr, nil)

	log.Fatal(err)
}

var statsTemplate = template.Must(template.New("").Parse(`
<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8">
	<link rel="stylesheet" href="https://unpkg.com/@picocss/pico@latest/css/pico.classless.min.css">
</head>
<body>
	<main>
		<hgroup>
			<h3>Hookshot</h3>
			<h4>download <a href="https://cowboyscott.itch.io">here</a></h4>
		</hgroup>
		<section>
			<hgroup>
				<h3>Matchmker</h2>
				<h4>{{ .PlayerCount }} player(s) connected
			</hgroup>
			<summary>Available servers</summary>
			<table>
				<thead>
					<tr>
						<th>ID</th>
						<th>Address</th>
						<th>Capacity</th>
						<th>Players</th>
					</tr>
				</thead>
				<tbody>
				{{ range $server := .AvailableServers }}
					<tr>
						<td>{{ $server.SessionID }}</td>
						<td>{{ $server.Address }}:{{ $server.Port }}</td>
						<td>{{ $server.Capacity }}</td>
						<td>{{ len $server.Players }}</td>
					</tr>
				{{ else }}
					<tr>
						<td colspan="4">No servers available!</td>
					</tr>
				{{ end }}
				</tbody>
			</table>
		</section>
	</main>
	<footer>
		<a href="https://cowboyscott.gg">by cowboyscott</a>
	</footer>
</body>
</html>
`))
