defmodule PortfolioWeb.PageController do
  use PortfolioWeb, :controller

  def home(conn, %{"locale" => lang}) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, cv: cv_data(lang), page_title: "Aimé Risson")
  end

  defp cv_data("en") do
    %{
      name: "Aimé RISSON",
      social: %{
        phone: "+33781517932",
        email: "aime.risson.1@gmail.com",
        github_link: "https://github.com/herissondev/",
        linkedin_link: "https://www.linkedin.com/in/aime-risson/"
      },
      about:
        "Passionate about new technologies, I aspire to master the entire development chain.",
      location: "Lyon, France",
      work_note: %{
        title: "Open for Remote Freelance Opportunities:",
        content:
          "Currently available for short to mid-term remote projects. Specializing in full-stack development, with a focus on Django, Vue.js, React, React Native or Elixir. Flexible on all aspects."
      },
      summary:
        "Currently in a Bachelor of Computer Science at IUT Lyon 1, I am looking for a 2-month internship in backend development.",
      experiences: [
        %{
          title: "Mobile / Backend development - Redesk",
          job_title: "Fullstack Development Internship",
          date: "April - July 2024",
          skills: ["Django", "CI/CD", "React Native", "Docker", "Expo"],
          description: "",
          summary:
            "Developed a whole react native offline first app & the backend from scratch using Expo and Django."
        },
        %{
          title: "Development of an interpreter - Archethic",
          job_title: "Backend Development Internship",
          link: "https://github.com/archethic-foundation/archethic-node",
          date: "July 2023",
          skills: ["Elixir", "GIT", "RPC", "Tests", "Agile"],
          description: "",
          summary:
            "Internship obtained following open source contributions in the Archethic blockchain project. Manipulation of AST (Abstract Syntax Tree) in Elixir: enriching a homegrown interpreted language."
        },
        %{
          title: "Industrial Business Application - CloudFlow",
          job_title: "Full Stack Development",
          date: "2022 - 2023",
          skills: ["Django", "CI/CD", "Next.js", "Kubernetes", "Docker", "Tests", "Monorepo"],
          description: "",
          summary:
            "Design, realization, and sale of an industrial maintenance planning application. \n Execution of backend and frontend."
        },
        %{
          title: "Refactoring Javascript to Typescript - Archethic",
          job_title: "Development Internship",
          link: "https://github.com/archethic-foundation/",
          date: "April 2023",
          skills: ["Typescript", "Javascript", "CI/CD", "Agile"],
          description: "",
          summary:
            "Internship obtained following open source contributions in the Archethic blockchain project. Refactoring of a Javascript SDK to a Typescript SDK."
        }
      ],
      formations: [
        %{
          title: "CS Engeniering School - ENSIMAG",
          job_title: nil,
          date: "2024 - 2027",
          skills: [],
          description: "",
          summary: ""
        },
        %{
          title: "Bachelor of Computer Science - IUT Lyon 1",
          job_title: "Major of promotion - Valedictorian",
          date: "2022 - 2025",
          skills: [],
          description: "",
          summary: ""
        },
        %{
          title: "Baccalaureate Mathematics - Computer Science",
          job_title: "With Highest Honors",
          date: "2022",
          skills: [],
          description: "",
          summary: ""
        }
      ],
      projects: [
        %{
          title: "AI Recipe",
          description:
            "Making recipes using AI to showcase the power of Intructor (Structured LLM output)",
          tags: ["Elixir", "Instructor", "JSON", "OPENAI"],
          link: "https://recipe.herisson.dev/"
        },
        %{
          title: "CloudFlow",
          description: "Creation of a company to sell industrial management software.",
          tags: ["Monorepo", "Kubernetes", "Django", "Next.js"]
        },
        %{
          title: "herisson.dev",
          description: "My personal website and blog. Made with Elixir & Phoenix",
          tags: ["Open Source", "Elixir", "Phoenix"],
          link: "https://herisson.dev"
        },
        %{
          title: "Vitalert - SAAS",
          description:
            "Sale of an online service for Vinted notifications. Up to 20 paying users.",
          tags: ["AWS Cognito", "AWS Lambda", "Kubernetes", "Docker", "FastApi"]
        },
        %{
          title: "Vinted Api Wrapper",
          description:
            "A Python package facilitating access to the Vinted API for searching new listings.",
          tags: ["Open Source", "Python", "PyPi"],
          link: "https://github.com/herissondev/vinted-api-wrapper"
        },
        %{
          title: "AEweb Github Action",
          link: "https://github.com/archethic-foundation/aeweb-github-action",
          description:
            "Development of a Github Action for easily hosting a website on the Archethic blockchain",
          tags: ["Open Source", "Github Action", "Javascript"]
        },
        %{
          title: "Serrata",
          link: "https://serrata.super-sympa.fr/",
          description: "Keyboard mashing game on the flags of the world. Made with friends!",
          tags: ["Open Source", "React", "ExpressJS"]
        }
      ]
    }
  end

  defp cv_data("fr") do
    %{
      name: "Aimé RISSON",
      social: %{
        phone: "+33781517932",
        email: "aime.risson.1@gmail.com",
        github_link: "https://github.com/herissondev/",
        linkedin_link: "https://www.linkedin.com/in/aime-risson/"
      },
      about:
        "Passionné par les nouvelles technologies, j'aspire à maitriser la chaine de développement complète.",
      location: "Lyon, France",
      work_note: %{
        title: "Ouvert aux opportunités de freelance à distance :",
        content:
          "Actuellement disponible pour des projets à distance de courte à moyenne durée. Spécialisé en développement full-stack, avec un focus sur Django, Vue.js, React, React Native ou Elixir. Flexible sur tous les aspects."
      },
      summary:
        "Actuellement en BUT Informatique à l'IUT Lyon 1, je suis à la recherche d'un stage de 2 mois en développement backend.",
      experiences: [
        %{
          title: "Développement Mobile / Backend - Redesk",
          job_title: "Stage en développement Fullstack",
          date: "Avril - Juillet 2024",
          skills: ["Django", "CI/CD", "React Native", "Docker", "Expo"],
          description: "",
          summary:
            "Développement d'une application react native offline first ainsi que la refonte du backend en utilisant respectivement Expo et Django Rest."
        },
        %{
          title: "Développement d'un interpréteur - Archethic",
          job_title: "Stage Développement Backend",
          link: "https://github.com/archethic-foundation/archethic-node",
          date: "Juillet 2023",
          skills: ["Elixir", "GIT", "RPC", "Tests", "Agile"],
          description: "",
          summary:
            "Stage obtenu suite à des contributions open source dans le projet blockchain Archethic. Manipulation d’AST (Abstract Syntax Tree) en Elixir : enrichissement d’un langage interprété maison."
        },
        %{
          title: "Application Métier Industriel - CloudFlow",
          job_title: "Développement Full Stack",
          date: "2022 - 2023",
          skills: ["Django", "CI/CD", "Next.js", "Kubernetes", "Docker", "Tests", "Monorepo"],
          description: "",
          summary:
            "Conception, réalisation et vente d’une application de planification de maintenance industrielle. \n Réalisation du backend et frontend."
        },
        %{
          title: "Refactoring Javascript  vers Typescript - Archethic",
          job_title: "Stage Développement",
          link: "https://github.com/archethic-foundation/",
          date: "Avril 2023",
          skills: ["Typescript", "Javascript", "CI/CD", "Agile"],
          description: "",
          summary:
            "Stage obtenu suite à des contributions open source dans le projet blockchain Archethic. Refactoring d'un SDK Javascript vers un SDK Typescript."
        }
      ],
      formations: [
        %{
          title: "École d'Ingénieur en Informatique - ENSIMAG",
          job_title: nil,
          date: "2024 - 2027",
          skills: [],
          description: "",
          summary: ""
        },
        %{
          title: "BUT informatique - IUT Lyon 1",
          job_title: "Major de promotion",
          date: "2022 - 2025",
          skills: [],
          description: "",
          summary: ""
        },
        %{
          title: "Baccalauréat Mathématiques - Informatique",
          job_title: "Mention Très Bien",
          date: "2022",
          skills: [],
          description: "",
          summary: ""
        }
      ],
      projects: [
        %{
          title: "Recette AI",
          description:
            "Créer des recettes en utilisant l'IA pour démontrer la puissance d'Intructor (sortie LLM structurée)",
          tags: ["Elixir", "Instructor", "JSON", "OPENAI"],
          link: "https://recipe.herisson.dev/"
        },
        %{
          title: "CloudFlow",
          description:
            "Création d'une entreprise pour vendre des logiciels de gestion industrielle.",
          tags: ["Monorepo", "Kubernetes", "Django", "Next.js"]
        },
        %{
          title: "herisson.dev",
          description: "Mon site personnel et blog. Fait avec Elixir & Phoenix",
          tags: ["Open Source", "Elixir", "Phoenix"],
          link: "https://herisson.dev"
        },
        %{
          title: "Vitalert - SAAS",
          description:
            "Vente d’un service en ligne pour notifications Vinted. Jusqu’à 20 utilisateurs payants.",
          tags: ["AWS Cognito", "AWS Lambda", "Kubernetes", "Docker", "FastApi"]
        },
        %{
          title: "Vinted Api Wrapper",
          description:
            "Un package Python facilitant l'accès à l'API Vinted pour rechercher de nouvelles annonces.",
          tags: ["Open Source", "Python", "PyPi"],
          link: "https://github.com/herissondev/vinted-api-wrapper"
        },
        %{
          title: "AEweb Github Action",
          link: "https://github.com/archethic-foundation/aeweb-github-action",
          description:
            "Développement d'une Action Github permettant d'héberger facilement un site web sur la blockchain Archethic",
          tags: ["Open Source", "Github Action", "Javascript"]
        },
        %{
          title: "Serrata",
          link: "https://serrata.super-sympa.fr/",
          description: "Jeu de tapage de clavier sur les drapeaux du monde. Fait entre amis !",
          tags: ["Open Source", "React", "ExpressJS"]
        }
      ]
    }
  end
end
