async function callBackend() {
    try {
        const response = await fetch("http://192.168.56.25:30008");
        const data = await response.json();

        document.getElementById("result").innerText =
            "Réponse: " + data.message + " | Service: " + data.service;

    } catch (error) {
        document.getElementById("result").innerText =
            "Erreur connexion backend";
    }
}