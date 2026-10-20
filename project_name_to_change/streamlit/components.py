from datetime import UTC, datetime
from pathlib import Path
from types import TracebackType
from typing import Literal, Self

import streamlit as st
import streamlit.components.v1 as components

CSS_PATH = Path(__file__).parent / "styles.css"


def app_footer() -> None:
    # `key` renders the container with an `st-key-app_footer` CSS class to style against.
    with st.container(key="app_footer"):
        st.caption(f"&#169; {datetime.now(UTC):%Y}")


def app_css() -> None:
    """Adds custom CSS to the Streamlit app."""
    # Streamlit wraps a .css file in <style> tags and keeps it out of the layout flow.
    st.html(CSS_PATH)


def app_js() -> None:
    """Function to render top-level custom JS for the entire application.

    This is required to add custom styles/behavior to custom components in iframes.
    """
    components.html(
        """
    <script>
        window.addEventListener('DOMContentLoaded', function () {
            console.log('Adding custom JS to the app');
        })
    </script>
    """,
        height=0,
    )


class Page:
    def __init__(
        self,
        page_title: str,
        page_layout: Literal["centered", "wide"] = "wide",
        page_icon: str | None = None,
        state_dependencies: list[dict[str, str]] | None = None,
    ):
        self.page_title = page_title
        self.page_layout = page_layout
        self.page_icon = page_icon

        if state_dependencies is None or not isinstance(state_dependencies, list):
            self.state_dependencies = []
        else:
            self.state_dependencies = state_dependencies

    def __enter__(self) -> Self:
        st.set_page_config(
            page_title=self.page_title,
            layout=self.page_layout,
            page_icon=self.page_icon,
            initial_sidebar_state="expanded",
        )

        for state_dep in self.state_dependencies:
            name = state_dep.get("name")
            if name is None:
                # Raise rather than skip: a malformed entry would otherwise leave the page unguarded.
                raise ValueError(f"`state_dependencies` entries require a `name` key, got: {state_dep!r}")

            if name not in st.session_state:
                error_msg = state_dep.get("error", f"`{name}` not found in state")
                redirect_page = state_dep.get("redirect_page", "page/home.py")

                st.session_state["page_error"] = error_msg
                st.switch_page(redirect_page)

        app_css()

        page_error = st.session_state.get("page_error")
        if page_error:
            st.error(page_error)
            del st.session_state["page_error"]  # Clear the error after displaying it

        st.title("Minimal Streamlit App")

        # NOTE: you can add components here that will appear on every page

        return self

    def __exit__(
        self, exc_type: type[BaseException] | None, exc_val: BaseException | None, exc_tb: TracebackType | None
    ) -> None:
        app_footer()
        app_js()
