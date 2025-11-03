const express = require('express');
const app = express();
const PORT = 8080;

app.get('/', (req, res) => {
  res.send('Hello World! This is v1 of my CI/CD application.');
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});