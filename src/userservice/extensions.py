#from prometheus_flask_exporter.multiprocess import GunicornInternalPrometheusMetrics
from prometheus_flask_exporter import PrometheusMetrics
"""
Extensions for app
"""

metrics = PrometheusMetrics.for_app_factory()

def setup_extensions(app):
    """
    Allows us to implement metrics and reset from testsuite.
    """
    metrics.init_app(app)
    return app
