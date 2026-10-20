import streamlit as st

pages = [
    st.Page("page/home.py", title="Home"),
    st.Page("page/blocked_page.py", title="Blocked Page"),
    # Add more pages here as needed
]
pg = st.navigation(pages)
pg.run()
