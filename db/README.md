Steps to deploy the database.

1) Download Flyway Command-line Tool and Maven Plugin https://flywaydb.org/getstarted/download

2) Replace the flyway.conf file with the one in the repo

3) Modify the flyway.conf file to include the database location and password

4) from command line >flyway migrate

This should execute all scripts in the PLSQL and SQL directory into the target database
