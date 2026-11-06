--!strict
-- A Service (server) or Controller (client). The bootstrap runs every Init, then every Start.
export type Lifecycle = {
	Name: string,
	Init: (() -> ())?,
	Start: (() -> ())?,
}

return {}
