# Mariadb Running Connection Tester

### Purpose

The Mariadb Running Connection Tester is a bash *simulator* that uses the Mariadb command line client to create a long-running connection to a server. This connection is kept alive by frequently sending a minimal query to the server. Faults in connectivity are logged with a timestamp for comparison with other processes that have the potential to lose connectivity.

### Setting up the Running Connection Tester
There are two steps to setting up the tester:

 1. In the SQL directory, you will find a SQL script "query.sql". You can use this as it is or edit it. All it needs to have is a query that costs nothing to run and can be seen in the processlist. The default query is:
 ```
select sleep(1) as zero, 1 as one;
 ```

 2. Edit the file simulator.cnf and configure the connection. The standard syntax for mariadb client configuration applies. Any value that can work with Mariadb client is acceptable including values for configuring SSL/TLS.
 
### Examples of running the Tester from the command line

```
./establish_connection.sh 
./establish_connection.sh  --help
./establish_connection.sh  --minutes=1 --interactive
./establish_connection.sh  --qpm_low=20
./establish_connection.sh  --cleanup
```    

### Testing your ability to connect

To run the script for 1 minute and view the activity during that time, use this command:

```
./establish_connection.sh  --minutes=1 --interactive
```

### Running as a background process

```
./establish_connection.sh 1>/dev/null & disown
```
    
### Available Options

```
This script can be run without options. Not indicating an option value will use the default.
  --interactive        # Run script with visible output to command line. Default is non-interactive.
  --minutes=10         # Indicate the number of minutes to run, default 525600 (1 year).
  --connections=2      # Indicate the number of connections maintained, default 1.
  --qpm_low            # Queries per minute, default 30.
  --cleanup            # If script is cancelled (ctrl+c or killed), processes and pipes must be removed.
                       # Use the cleanup option to start over.
  --test               # Test connect to database and display script version. Always interactive.
  --version            # Test connect to database and display script version. Always interactive.
  --help               # Display the help menu. Always interactive.
```

### Minimum privileges necessary for user

The user account that makes the connection based on the values in simulator.cnf needs to have only enough privileges to connect and run `select 1;`. For example:
```
GRANT USAGE ON *.* TO `appli`@`%`;
```

### Queries Per Minute

The Running Connection Tester will run whatever sql scripts that are placed in the "SQL" directory, chosen at random. Using one script is recommended and one is provided. A minimal query is recommended, but any query, DML, or SQL code block that you prefer can be used. The default is to run 30 queries per minute, which will detect and log a break in connectivity within 2 seconds.

### Stopping the Tester prematurely

When running in interactive mode, you can quit a running connection pool at any time with ctrl+c. This will leave background processes running that will require a clean-up. Run the script again with the cleanup option:
```
./establish_connection.sh --cleanup
```
For non-interactive use, you can perform a graceful shutdown that does not require clean up. Stop the running process using the stop_run.sh script:
```
./stop_run.sh
```

### Getting a history of disconnects

If a fault in communication between client and server occurs, this script logs the error in the file CONN_ERRORS. The errors include a timestamp, which can be compared to any other process that is maintaining a similar connection. Example of the CONN_ERRORS log:

```
2025-05-20 16:47:55 CONNECTION ESTABLISHED
2025-05-20 16:49:03 ERROR 2013 (HY000) at line 667: Lost connection to server during query
2025-05-20 16:49:03 ERROR 2006 (HY000) at line 688: Server has gone away
2025-05-20 16:49:03 ERROR 2006 (HY000) at line 709: Server has gone away
2025-05-20 16:49:05 ERROR 2002 (HY000): Can't connect to server on '192.168.8.111' (110)
2025-05-20 16:49:16 ERROR 2002 (HY000): Can't connect to server on '192.168.8.111' (110)
2025-05-20 16:49:27 ERROR 2002 (HY000): Can't connect to server on '192.168.8.111' (110)
2025-05-20 16:49:38 CONNECTION ESTABLISHED
2025-05-20 16:49:51 EXITED INTENTIONALLY
```

### History of this script

The Mariadb Running Connection Tester is a modification of the Mariadb Connection Pool Simulator script, also by Edward Stoever.

Ref: Support ticket 215493
