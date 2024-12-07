<?php
$servername = "your-rds-endpoint"; // Get this from the Terraform output
$username = "admin"; // The username for the RDS MySQL instance
$password = "your-password"; // The password for the RDS MySQL instance
$dbname = "sampledb"; // The database name

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
  die("Connection failed: " . $conn->connect_error);
}

// Query the users table
$sql = "SELECT id, name, email FROM users";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
  // Output data of each row
  echo "<h1>User List</h1>";
  echo "<table border='1'><tr><th>ID</th><th>Name</th><th>Email</th></tr>";
  while($row = $result->fetch_assoc()) {
    echo "<tr><td>" . $row["id"]. "</td><td>" . $row["name"]. "</td><td>" . $row["email"]. "</td></tr>";
  }
  echo "</table>";
} else {
  echo "0 results";
}

$conn->close();
?>