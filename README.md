SMTP-OM-CORE
=========================================

Project Contents:
	api - REST APIs used by the Core OM Services.  These are mostly program area specific
	swagger-ui - POM file to download and package the swagger-ui app so that it can be run in an OSGI container
	
To build this project use

    mvn install (note swagger-ui component must be triggered seperately)

Fuse Pre-requisites:
	Fuse 6.3
	features:install war
	features:install camel-jetty
	features:install camel-servlet (may not be required)
	
To deploy the project in OSGi. For example using Apache Karaf.
You can run the following command from its shell:

    osgi:install -s mvn:com.smtp/smtp-om-glvalidation/1.0.0-SNAPSHOT

To deploy swagger UI in OSGi:
	install -s war:file:{build directory}//swagger-ui.war?Web-ContextPath=swagger-ui


For more help see the Apache Camel documentation

    http://camel.apache.org/
