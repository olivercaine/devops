var express = require('express')

var server = express()
server.use('/', express.static(__dirname + '/'))

server.get('/*', function (req, res) {
  res.sendFile(__dirname + '/index.html')
})

// Repo comment
var port = process.env.PORT || 3000
server.listen(port, function () {
  console.log('server listening on port ' + port)
})
