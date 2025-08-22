<?php
// SPDX-License-Identifier: MIT
// WARNING: This is intentionally vulnerable code for testing purposes only

// SQL Injection vulnerability
if (isset($_GET['id'])) {
    $id = $_GET['id'];
    // Vulnerable: Direct concatenation
    $query = "SELECT * FROM users WHERE id = " . $id;
    echo "<!-- Debug: Query would be: $query -->\n";
}

// Command Injection vulnerability
if (isset($_GET['ping'])) {
    $host = $_GET['ping'];
    // Vulnerable: Direct command execution
    $output = shell_exec("ping -c 1 " . $host);
    echo "<pre>$output</pre>";
}

// Path Traversal vulnerability
if (isset($_GET['file'])) {
    $file = $_GET['file'];
    // Vulnerable: No path validation
    if (file_exists($file)) {
        echo "<pre>" . htmlspecialchars(file_get_contents($file)) . "</pre>";
    }
}

// XSS vulnerability
if (isset($_GET['name'])) {
    $name = $_GET['name'];
    // Vulnerable: No output encoding
    echo "<h1>Welcome, $name!</h1>";
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Vulnerable Test App</title>
</head>
<body>
    <h1>Vulnerable Test Application</h1>
    <p>This application contains intentional vulnerabilities for testing purposes.</p>
    
    <h2>Test Endpoints:</h2>
    <ul>
        <li>SQL Injection: /?id=1</li>
        <li>Command Injection: /?ping=127.0.0.1</li>
        <li>Path Traversal: /?file=index.php</li>
        <li>XSS: /?name=Guest</li>
    </ul>
</body>
</html>