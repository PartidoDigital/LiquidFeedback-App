FROM debian

# Components version
ENV LF_CORE_VERSION 3.2.1
ENV LF_FRND_VERSION 3.2.1
ENV MOONBRIDGE_VERSION 1.0.1
ENV WEBMCP_VERSION 2.0.3

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# 1. Install necessary dependencies
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y build-essential wget apt-utils
RUN apt-get install -y lua5.2 liblua5.2-dev
RUN apt-get install -y postgresql libpq-dev
RUN apt-get install -y pmake
RUN apt-get install -y imagemagick
RUN apt-get install -y exim4
RUN apt-get install -y python-pip
RUN pip install markdown2

RUN apt-get install -y libpq-dev postgresql-server-dev-9.6
RUN cp -rf /usr/include/lua5.2/* /usr/include
RUN cp -rf /usr/include/postgresql/* /usr/include
RUN cp -rf /usr/include/postgresql/9.6/server/* /usr/include

# 2. Ensure that the user account of your web server has access to the database
USER postgres
RUN /etc/init.d/postgresql start && \
	createuser --no-superuser --createdb --no-createrole www-data

# 3. Install and configure LiquidFeedback-Core
USER root
RUN cd /
RUN wget -c http://www.public-software-group.org/pub/projects/liquid_feedback/backend/v${LF_CORE_VERSION}/liquid_feedback_core-v${LF_CORE_VERSION}.tar.gz
RUN tar xzvf liquid_feedback_core-v${LF_CORE_VERSION}.tar.gz
RUN cd liquid_feedback_core-v${LF_CORE_VERSION} && make
RUN mkdir -p /opt/liquid_feedback_core
RUN cd /liquid_feedback_core-v${LF_CORE_VERSION} && \
	cp -f core.sql lf_update lf_update_issue_order lf_update_suggestion_order /opt/liquid_feedback_core

COPY createdb.sql /tmp
RUN cd /opt/liquid_feedback_core
RUN /etc/init.d/postgresql start && \
	su - www-data -s /bin/sh -c 'createdb liquid_feedback' && \
	# su - www-data -s /bin/sh -c 'createlang plpgsql liquid_feedback' && \
	su - www-data -s /bin/sh -c '/usr/bin/psql -v ON_ERROR_STOP=1 -f /opt/liquid_feedback_core/core.sql liquid_feedback' && \
	su - www-data -s /bin/sh -c '/usr/bin/psql -f /tmp/createdb.sql liquid_feedback'

# 4. Install Moonbridge
USER root
RUN cd /
RUN wget -c http://www.public-software-group.org/pub/projects/moonbridge/v${MOONBRIDGE_VERSION}/moonbridge-v${MOONBRIDGE_VERSION}.tar.gz
RUN tar xzvf moonbridge-v${MOONBRIDGE_VERSION}.tar.gz
RUN apt-get install -y libbsd-dev
RUN mkdir -p /opt/moonbridge
RUN cd moonbridge-v${MOONBRIDGE_VERSION} ; \
	pmake MOONBR_LUA_PATH=/opt/moonbridge/?.lua && \
	cp -f moonbridge /opt/moonbridge/ && \
	cp -f moonbridge_http.lua /opt/moonbridge/

# 5. Install WebMCP
USER root
RUN cd /
RUN wget -c http://www.public-software-group.org/pub/projects/webmcp/v${WEBMCP_VERSION}/webmcp-v${WEBMCP_VERSION}.tar.gz
RUN tar xzvf webmcp-v${WEBMCP_VERSION}.tar.gz
RUN mkdir -p /opt/webmcp
RUN cd webmcp-v${WEBMCP_VERSION} && make && \
	cp -RL framework/* /opt/webmcp/

# 6. Install the LiquidFeedback-Frontend
USER root
RUN cd /
RUN wget -c http://www.public-software-group.org/pub/projects/liquid_feedback/frontend/v${LF_FRND_VERSION}/liquid_feedback_frontend-v${LF_FRND_VERSION}.tar.gz
RUN tar xzvf liquid_feedback_frontend-v${LF_FRND_VERSION}.tar.gz
RUN rm -rf /opt/liquid_feedback_frontend && \
	mv /liquid_feedback_frontend-v${LF_FRND_VERSION} /opt/liquid_feedback_frontend && \
	mkdir -p /opt/liquid_feedback_frontend/tmp && \
	chown -R www-data /opt/liquid_feedback_frontend/tmp
COPY translations.es.lua /opt/liquid_feedback_frontend/locale/translations.es.lua

# 7. Configure mail system
# Skipping it for now

# 8. Configure the LiquidFeedback-Frontend
COPY myconfig.lua /opt/liquid_feedback_frontend/config/myconfig.lua

# 9. Setup regular execution of lf_update and related commands
COPY lf_updated /opt/liquid_feedback_core/lf_updated
RUN chmod +x /opt/liquid_feedback_core/lf_updated 

# 10. Start the system
CMD	echo "Starting LiquidFeedback..." ; \
	/etc/init.d/postgresql start ; \
	su - www-data -s /bin/sh -c "/opt/moonbridge/moonbridge /opt/webmcp/bin/mcp.lua /opt/webmcp/ /opt/liquid_feedback_frontend/ main myconfig" ; \
	/opt/liquid_feedback_core/lf_updated

# Cleaning up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN rm -rf /usr/include /usr/share/man /usr/share/doc