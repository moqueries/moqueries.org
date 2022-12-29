import unittest
from lambdas.origin_request.index import lambda_handler


class TestLambdaHandler(unittest.TestCase):
    def test_regular_file(self):
        # ASSEMBLE
        uri = "/something-somewhere/this-file.foo"
        event = {
            "Records": [
                {
                    "cf": {
                        "request": {
                            "uri": uri
                        }
                    }
                }
            ]
        }

        # ACT
        request = lambda_handler(event, None)

        # ASSERT
        self.assertEqual(request["uri"], uri)

    def test_dir(self):
        # ASSEMBLE
        event = {
            "Records": [
                {
                    "cf": {
                        "request": {
                            "uri": "/something-somewhere/this-dir"
                        }
                    }
                }
            ]
        }

        # ACT
        request = lambda_handler(event, None)

        # ASSERT
        self.assertEqual(request["uri"], "/something-somewhere/this-dir/index.html")

    def test_file_w_dot_parent(self):
        # ASSEMBLE
        uri = "/something.somewhere/this-file.foo"
        event = {
            "Records": [
                {
                    "cf": {
                        "request": {
                            "uri": uri
                        }
                    }
                }
            ]
        }

        # ACT
        request = lambda_handler(event, None)

        # ASSERT
        self.assertEqual(request["uri"], uri)

    def test_dir_w_dot_parent(self):
        # ASSEMBLE
        event = {
            "Records": [
                {
                    "cf": {
                        "request": {
                            "uri": "/something.somewhere/this-dir"
                        }
                    }
                }
            ]
        }

        # ACT
        request = lambda_handler(event, None)

        # ASSERT
        self.assertEqual(request["uri"], "/something.somewhere/this-dir/index.html")

    def test_dir_w_trailing_slash(self):
        # ASSEMBLE
        event = {
            "Records": [
                {
                    "cf": {
                        "request": {
                            "uri": "/something-somewhere/this-dir/"
                        }
                    }
                }
            ]
        }

        # ACT
        request = lambda_handler(event, None)

        # ASSERT
        self.assertEqual(request["uri"], "/something-somewhere/this-dir/index.html")

    def test_dot_dir_w_trailing_slash(self):
        # ASSEMBLE
        event = {
            "Records": [
                {
                    "cf": {
                        "request": {
                            "uri": "/something-somewhere/this.dir/"
                        }
                    }
                }
            ]
        }

        # ACT
        request = lambda_handler(event, None)

        # ASSERT
        self.assertEqual(request["uri"], "/something-somewhere/this.dir/index.html")


if __name__ == '__main__':
    unittest.main()
