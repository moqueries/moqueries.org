import os

index_file = "index.html"


def lambda_handler(event, _):
    request = event['Records'][0]['cf']['request']
    uri = request['uri']

    if uri.endswith("/"):
        request['uri'] = uri + index_file
    else:
        fn = os.path.basename(uri)
        if "." not in fn:
            request['uri'] = uri + "/" + index_file

    return request
