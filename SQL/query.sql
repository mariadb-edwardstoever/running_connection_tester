-- Script by Edward Stoever for Mariadb Support
-- Script distributed with MARIADB RUNNING CONNECTION TESTER

-- This SQL script can contain any valid STATEMENTS or ANONYMOUS BLOCKS. This script will be run by the running connection tester.
-- The reason to run this script is to have some activity and communication between the client and server which will
-- keep the session alive over a long period of time. It will also ensure that any interruption in the communication 
-- from client to server is detected quickly. For this reason, a minimal query that is run once every 2 seconds is recommended.

-- The minimum query possible which communicates from client to server and from server to client is "select 1;"
-- select 1;
-- Another minimum query is "select now();"
-- select now();

-- The previous queries will run so quickly that it is impracticle to see any activity of the session the processlist.
-- So, if you want to see a query running by the session in the server's processlist, add sleep(1). For example:
select sleep(1) as zero, 1 as one;

-- If you want a lasting record in the database of the activity from this script, try an insert or an update.
-- If you insert 30 times per minute, the table will grow to about 15 million rows in 1 year. It sounds like a lot, 
-- but if the table only has a few small columns, the datafile will probably be relatively small.
-- Alternatively, you could update the only row of a table each time the script is run. 
