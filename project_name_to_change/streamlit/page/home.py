import streamlit as st

from project_name_to_change.streamlit.components import Page


def toggle_blocked_page() -> None:
    if "my_required_state" in st.session_state:
        del st.session_state["my_required_state"]
    else:
        st.session_state["my_required_state"] = True


with Page(
    page_title="Streamlit - Home",
) as page:
    st.header("Welcome!")

    st.write("This is a VERY minimal template for a multi-page streamlit app.")

    st.subheader("Adding Pages")
    st.write(
        """
        You can add as many pages as you want, just:
        1. Create a new file in the `page` directory
        2. Add it to the `pages` list in `app.py`.
        """
    )

    st.divider()

    st.subheader("Custom Page Class")
    st.write(
        """
        The template ships with a custom `Page` class that gives you a minimal set of convenience features,
        like state dependency checks and global CSS/JS.

        Try accessing the 'Blocked Page' from the menu - you should be redirected to the home page with an
        error! Click the button below to unlock/lock it. To understand how this works, check out the `Page`
        class in `components.py` and look at how `state_dependencies` are used in `blocked_page.py`.
        """
    )

    st.button(
        "Unlock the Blocked Page" if "my_required_state" not in st.session_state else "Lock the Blocked Page",
        icon="🔓",
        on_click=toggle_blocked_page,
    )

    st.divider()

    st.subheader("Custom CSS/JS")

    st.write(
        """
        The `app_css` and `app_js` functions in `components.py` are called on every page, so you can
        add global styles or scripts there to customize your app. There's a simple example in `app_css`
        that makes the footer positionally fixed at the bottom of the page.
        """
    )

    st.write("Have fun customizing this template for your Streamlit projects!")
