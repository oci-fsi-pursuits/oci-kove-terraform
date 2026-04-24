FROM fnproject/python:3.11-dev as build-stage
WORKDIR /function

ADD requirements.txt /function/
RUN pip3 install --target /python/ -r requirements.txt && rm -fr ~/.cache/pip /tmp* requirements.txt

ADD . /function/
RUN chmod -R o+r /function

FROM fnproject/python:3.11
WORKDIR /function
COPY --from=build-stage /python /python
COPY --from=build-stage /function /function
RUN chmod -R o+r /function

ENV PYTHONPATH=/python
CMD ["autoscale_func.handler"]
