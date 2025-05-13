from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import sys
from urllib.parse import parse_qs, urlparse, urlencode

class StravaCallbackHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Parse the URL and query parameters
        parsed_path = urlparse(self.path)
        query_params = parse_qs(parsed_path.query)
        
        # Get the authorization code and state
        code = query_params.get('code', [None])[0]
        state = query_params.get('state', [None])[0]
        error = query_params.get('error', [None])[0]
        
        print(f"Received callback with code: {code} and state: {state}")
        
        # Construct the redirect URL with the same parameters
        redirect_params = {}
        if code:
            redirect_params['code'] = code
        if state:
            redirect_params['state'] = state
        if error:
            redirect_params['error'] = error
            
        redirect_url = f"fundracer://callback?{urlencode(redirect_params)}"
        
        self.send_response(302)  # Temporary redirect
        self.send_header('Location', redirect_url)
        self.end_headers()

def run(server_class=HTTPServer, handler_class=StravaCallbackHandler, port=8081):
    try:
        server_address = ('', port)
        httpd = server_class(server_address, handler_class)
        print(f'Starting server on port {port}...')
        httpd.serve_forever()
    except OSError as e:
        print(f"Error starting server: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nShutting down server...")
        httpd.server_close()
        sys.exit(0)

if __name__ == '__main__':
    run() 