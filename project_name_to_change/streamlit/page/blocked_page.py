import streamlit as st

from project_name_to_change.streamlit.components import Page

with Page(
    page_title="Streamlit - Blocked Page",
    state_dependencies=[
        {
            "name": "my_required_state",
            "error": "You must set `my_required_state` in the session state to access this page.",
            "redirect_page": "page/home.py",
        }
    ],
) as page:
    st.header("🚫 Blocked Page")
    st.write(
        """
        Unless you set the required state (`my_required_state`) in the session state,
        you won't be able to see this page!
        """
    )
