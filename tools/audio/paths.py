"""Where generated audio takes are kept (outside the repo, so a take can be swapped without
regenerating). Default ~/sa3-review; set SA3_REVIEW to use another folder."""
from __future__ import annotations

import os
from pathlib import Path

REVIEW_ROOT = Path(os.environ.get("SA3_REVIEW", Path.home() / "sa3-review"))
