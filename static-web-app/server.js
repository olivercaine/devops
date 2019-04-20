var express = require('express')

var app = express()
app.use('/', express.static(__dirname + '/'))
app.get('/*', function (req, res) {
  res.sendFile(__dirname + '/index.html')
})

var port = process.env.PORT || 3000
var server = app.listen(port, function () {
  console.log('server listening on port ' + port)
})

function shutDown () {
  console.log('Received kill signal, shutting down gracefully')
  server.close(() => {
    console.log('Closed out remaining connections')
    process.exit(0)
  })
}

process.on('SIGTERM', shutDown)
process.on('SIGINT', shutDown)
