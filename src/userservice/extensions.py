"""
Extensions for app
"""
import os
from prometheus_flask_exporter.multiprocess import GunicornPrometheusMetrics
#from prometheus_flask_exporter import PrometheusMetrics
import tempfile
metrics = GunicornPrometheusMetrics.for_app_factory()

def setup_extensions(app):
    """
    Allows us to implement metrics and reset from testsuite.
    """
    os.environ["PROMETHEUS_MULTIPROC_DIR"] = tempfile.gettempdir()
    metrics.init_app(app)
    return app
