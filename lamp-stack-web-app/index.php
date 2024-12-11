<?php
require 'vendor/autoload.php';  // Ensure the AWS SDK is included

use Aws\Ssm\SsmClient;
use Dotenv\Dotenv;
use Aws\Exception\AwsException;

// Load environment variables from .env file
$dotenv = Dotenv::createImmutable(__DIR__);
$dotenv->load();

$ssmClient = new SsmClient([
  'region' => 'eu-west-2', // Change to your AWS region
  'version' => 'latest',
]);

try {
  // Fetch DB password from SSM Parameter Store
  $passwordResult = $ssmClient->getParameter([
    'Name' => '/lamp/rds_password',
    'WithDecryption' => true,
  ]);
  $rds_password = $passwordResult['Parameter']['Value'];

  // Fetch DB endpoint from SSM Parameter Store
  $rds_endpoint = $ssmClient->getParameter([
    'Name' => '/lamp/rds_endpoint', // Ensure you use the correct name for the endpoint
    'WithDecryption' => true,
  ]);
  $dbEndpoint = $endpointResult['Parameter']['Value'];

  // You can now use $dbPassword and $dbEndpoint as needed
} catch (AwsException $e) {
  // Output error message if fails
  echo "Error fetching parameter from SSM: " . $e->getMessage() . "\n";
  exit;  // Exit if fetching parameters fails
} catch (Exception $e) {
  // Handle any other exceptions
  echo "An error occurred: " . $e->getMessage() . "\n";
  exit;  // Exit if there is a general error
}

$username = "admin"; // The username for the RDS MySQL instance
$dbname = "sampledb"; // The database name

// Create connection
$conn = new mysqli($dbEndpoint, $username, $rds_password, $dbname);

// Check connection
if ($conn->connect_error) {
  die("Connection failed: " . $conn->connect_error);
}

// Query the users table
$sql = "SELECT id, name, email FROM users";
$result = $conn->query($sql);

if ($result && $result->num_rows > 0) {
  echo "<h1>User List</h1>";
  echo "<table border='1'><tr><th>ID</th><th>Name</th><th>Email</th></tr>";

  while ($row = $result->fetch_assoc()) {
    echo "<tr>";
    echo "<td>" . htmlspecialchars($row['id']) . "</td>";
    echo "<td>" . htmlspecialchars($row['email']) . "</td>";
    echo "</tr>";
  }
  echo "</table>";
} else {
  echo "0 results found.";
}

// Close the connection
$conn->close();
