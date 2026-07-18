#!/usr/bin/env python3
"""
clean_names.py

A Python function similar to R's janitor::clean_names(), for standardizing column names
(or any list of names) into consistent snake_case.

Handles:
  - camelCase / PascalCase -> snake_case boundaries
  - spaces, punctuation, special characters -> underscores
  - repeated/leading/trailing underscores cleaned up
  - names starting with a digit -> prefixed (e.g. "2019_cases" -> "x_2019_cases")
  - duplicate names after cleaning -> suffixed _2, _3, ... to stay unique

Usage:
    from clean_names import clean_names

    # On a pandas DataFrame (returns a copy with cleaned columns):
    df_clean = clean_names(df)

    # On a plain list of names (returns a list):
    clean_names(["Sample ID", "%GC content", "2019 Cases"])
    # -> ['sample_id', 'gc_content', 'x_2019_cases']
"""

import re
from collections import Counter

try:
    import pandas as pd
    _HAS_PANDAS = True
except ImportError:
    _HAS_PANDAS = False


def clean_names(df_or_names):
    """
    Clean column names the way janitor::clean_names() does (snake_case).

    Parameters
    ----------
    df_or_names : pandas.DataFrame or list/iterable of str
        If a DataFrame, returns a COPY with cleaned column names.
        If a list/iterable of strings, returns a list of cleaned names
        in the same order.

    Returns
    -------
    pandas.DataFrame or list of str
    """
    is_df = _HAS_PANDAS and isinstance(df_or_names, pd.DataFrame)
    names = list(df_or_names.columns) if is_df else list(df_or_names)

    cleaned = [_clean_one(name) for name in names]
    cleaned = _dedupe(cleaned)

    if is_df:
        out = df_or_names.copy()
        out.columns = cleaned
        return out
    return cleaned


def _clean_one(name):
    name = str(name).strip()

    # Treat percent sign specially: represent '%' as the word 'percent'
    # wrapped with underscores so it survives the non-alphanumeric
    # replacement step as a distinct token (e.g. "%GC" -> "percent_gc").
    name = name.replace('%', '_percent_')

    # Insert an underscore at camelCase boundaries: "fooBar" -> "foo_Bar"
    name = re.sub(r'(?<=[a-z0-9])(?=[A-Z])', '_', name)

    # Replace any run of non-alphanumeric characters with a single underscore
    name = re.sub(r'[^0-9a-zA-Z]+', '_', name)

    name = name.lower()

    # Collapse repeated underscores, strip leading/trailing ones
    name = re.sub(r'_+', '_', name).strip('_')

    if not name:
        name = "unnamed"

    # Names can't start with a digit -- prefix with x_, matching janitor/make.names
    if re.match(r'^[0-9]', name):
        name = f"x_{name}"

    return name


def _dedupe(names):
    """Append _2, _3, ... to any name that appears more than once, in order."""
    total_counts = Counter(names)
    seen = Counter()
    result = []
    for n in names:
        seen[n] += 1
        if total_counts[n] > 1:
            result.append(n if seen[n] == 1 else f"{n}_{seen[n]}")
        else:
            result.append(n)
    return result


if __name__ == '__main__':
    # Quick self-test / demo when run directly
    sample = ["Sample ID", "%GC content", "2019 Cases", "Read Count", "read_count",
              "  leading space", "trailing space  ", "CamelCaseName", "already_snake"]
    for original, cleaned in zip(sample, clean_names(sample)):
        print(f"{original!r:30s} -> {cleaned!r}")
