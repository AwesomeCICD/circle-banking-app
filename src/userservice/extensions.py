"""
Extensions for app
"""
import os
import tempfile
from prometheus_flask_exporter.multiprocess import GunicornPrometheusMetrics
#from prometheus_flask_exporter import PrometheusMetrics
os.environ["PROMETHEUS_MULTIPROC_DIR"] = tempfile.gettempdir()
metrics = GunicornPrometheusMetrics.for_app_factory()

def setup_extensions(app):
    """
    Allows us to implement metrics and reset from testsuite.
    """
    metrics.init_app(app)
    return app
