function collapsePanel() {
    var navText = document.getElementsByClassName("nav-text");
    for (i = 0; i < navText.length; i++) {
        if (navText[i].style.display === "none") {
            navText[i].style.display = "inline-block";
            document.getElementById("CollapsePanelLink").innerText = "Collaspe Panel";
        }
        else {
            navText[i].style.display = "none";
            document.getElementById("CollapsePanelLink").innerText = "Expand Panel";
        }
    }
}