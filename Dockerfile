FROM planitar/base

RUN apt-get install -y build-essential supervisor nginx-light && apt-get clean
RUN apt-get install -y python-cairo libgcrypt11 python-virtualenv python-dev && apt-get clean

RUN adduser --system --home /opt/graphite graphite

RUN sudo -u graphite virtualenv --system-site-packages ~graphite/env

ADD graphite/requirements.txt /tmp/graphite_reqs.txt
RUN sudo -u graphite HOME=/opt/graphite /bin/sh -c ". ~/env/bin/activate && pip install -r /tmp/graphite_reqs.txt"
RUN rm /tmp/graphite_reqs.txt

RUN mkdir -p /opt/grafana && \
    curl http://grafanarel.s3.amazonaws.com/grafana-1.6.1.tar.gz | \
    tar xzvf - -C /opt/grafana --strip-components 1

ADD supervisor/ /etc/supervisor/conf.d/

ADD nginx/nginx.conf /etc/nginx/

ADD graphite/app_settings.py /opt/graphite/webapp/graphite/
ADD graphite/local_settings.py /opt/graphite/webapp/graphite/
ADD graphite/wsgi.py /opt/graphite/webapp/graphite/
ADD graphite/mkadmin.py /opt/graphite/webapp/graphite/
ADD graphite/carbon.conf /opt/graphite/conf/
ADD graphite/storage-schemas.conf /opt/graphite/conf/
ADD graphite/storage-aggregation.conf /opt/graphite/conf/

ADD grafana/config.js /opt/grafana/

RUN sed -i "s#^\(SECRET_KEY = \).*#\1\"`python -c 'import os; import base64; print(base64.b64encode(os.urandom(40)))'`\"#" /opt/graphite/webapp/graphite/app_settings.py
RUN sudo -u graphite HOME=/opt/graphite PYTHONPATH=/opt/graphite/lib/ /bin/sh -c "cd ~/webapp/graphite && ~/env/bin/python manage.py syncdb --noinput"
RUN sudo -u graphite HOME=/opt/graphite PYTHONPATH=/opt/graphite/lib/ /bin/sh -c "cd ~/webapp/graphite && ~/env/bin/python mkadmin.py"

# nginx:grafana nginx:graphite carbon/plaintext carbon/pickle
EXPOSE 80 81 2003 2004

CMD exec supervisord -n
