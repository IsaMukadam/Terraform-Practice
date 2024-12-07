<?php
// Database connection parameters
$servername = "your-rds-endpoint"; // RDS endpoint
$username = "admin";
$password = "your-password";
$dbname = "sampledb";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
  die("Connection failed: " . $conn->connect_error);
}
?>