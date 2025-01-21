document.addEventListener("DOMContentLoaded", function () {
  // Typing and deleting effect for multiple languages
  const words = ["Hello,", "Bonjour,", "こんにちは,", "你好,", "नमस्ते,", "안녕하세요,", "Hola,"];
  let i = 0;
  let timer;

  function typingEffect() {
    let word = words[i].split("");

    function loopTyping() {
      if (word.length > 0) {
        document.getElementById("word").innerHTML += word.shift();
      } else {
        deletingEffect(); // Once typing finishes, start deleting
        return;
      }
      timer = setTimeout(loopTyping, 250); // Typing speed
    }

    clearTimeout(timer); // Clear any existing timeout before starting a new typing effect
    loopTyping();
  }

  function deletingEffect() {
    let word = words[i].split("");

    function loopDeleting() {
      if (word.length > 0) {
        word.pop();
        document.getElementById("word").innerHTML = word.join("");
      } else {
        // Move to the next word or reset if we're at the end
        i = (i + 1) % words.length; // Cycle through words
        typingEffect(); // Start typing the next word
        return;
      }
      timer = setTimeout(loopDeleting, 100); // Deleting speed
    }

    clearTimeout(timer); // Clear any existing timeout before starting a new deleting effect
    loopDeleting();
  }

  // Back-to-top button logic
  function scrollFunction() {
    const backToTopBtn = document.getElementById("backToTopBtn");
    if (!backToTopBtn) return; // Avoid errors if button is not found
    backToTopBtn.style.display =
      document.documentElement.scrollTop > 20 || document.body.scrollTop > 20 ? "block" : "none";
  }

  window.onscroll = scrollFunction;

  const backToTopBtn = document.getElementById("backToTopBtn");
  if (backToTopBtn) {
    backToTopBtn.addEventListener("click", () => {
      document.body.scrollTop = 0;
      document.documentElement.scrollTop = 0;
    });
  }

  // Footer template fetch and insertion
  fetch("template.html") // Replace with the actual template path
    .then((response) => {
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      return response.text();
    })
    .then((html) => {
      // Parse the HTML response
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");

      // Update the current year in all elements with the class "current-year"
      doc.querySelectorAll(".current-year").forEach((el) => {
        el.textContent = new Date().getFullYear();
      });

      // Insert footer content
      const footerHTML = doc.querySelector(".footer").outerHTML;
      document.getElementById("footer-placeholder").innerHTML = footerHTML;
    })
    .catch((error) => {
      console.error("Error fetching the template:", error);
    });

  // Start the typing effect
  typingEffect();
});
