package main

import "embed"

//go:embed all:static
var webFiles embed.FS
