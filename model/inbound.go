package model

type Inbound struct {
	Id             int
	Listen         string
	Port           int
	Protocol       string
	Settings       string
	StreamSettings string
	Tag            string
	Sniffing       string
	Allocate       string
	Enable         bool
	Remark         string
	ExpiryTime     int64
	Total          int64
	Up             int64
	Down           int64
	UserId         int
	ClientStats    []interface{}
}
