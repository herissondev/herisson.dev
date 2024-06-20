defmodule PortfolioWeb.CompetenceController do
  use PortfolioWeb, :controller

  @competences [
    %{
      title: "Réaliser",
      id: "sdlkfjslkkldkfjlskdjf",
      tags: ["Dev"],
      description:
        "Développer - c'est-à-dire concevoir, coder, tester et intégrer — une solution informatique pour un client."
    },
    %{
      title: "Optimiser",
      id: "sdlkfjsl4dkfjlskdjf",
      tags: ["Dev"],
      description:
        "Proposer des applications informatiques optimisées en fonction de critères spécifiques : temps d’exécution, précision, consommation de ressources... "
    },
    %{
      title: "Administrer",
      id: "sdlkfjscqwldkfjlskdjf",
      tags: ["Dev"],
      description:
        "Installer, configurer, mettre à disposition, maintenir en conditions opérationnelles des infrastructures, des services et des réseaux et optimiser le système informatique d'une organisation"
    },
    %{
      title: "Gérer",
      id: "sdlkfjsl^sdflks,dfdkfjlskdjf",
      tags: ["Dev"],
      description:
        "Concevoir, gérer, administrer et exploiter les données de l'entreprise et mettre à disposition toutes les informations pour un bon pilotage de l'entreprise"
    },
    %{
      title: "Conduire",
      id: "sdlkfjsldkzefjlskdjf",
      tags: ["Dev"],
      description:
        "Satisfaire les besoins des utilisateurs au regard de la chaine de valeur du client, organiser et piloter un projet informatique avec des méthodes classiques ou agiles"
    },
    %{
      title: "Collaborer",
      id: "sdlkfjsldsdfhhkfjlskdjf",
      tags: ["Dev"],
      description:
        "Acquérir, développer et exploiter les aptitudes nécessaires pour travailler efficacement dans une équipe informatique"
    }
  ]

  @projects [
    %{
      title: "Coinchotte",
      description: "Création d'une application de choinche en ligne. Travail en équipe.",
      tags: ["Django", "Déploiement CI/CD", "Kubernetes", "WebSockets"]
    },
    %{
      title: "SecureWay",
      description:
        "Gestion des déplacements d'une ambulance dans des terrains escarpés avec trajets optimisés. Travail d'équipe avec communication intensive.",
      tags: ["Java", "Algorithmes"]
    },
    %{
      title: "FrancoList",
      description: "Application pour faire des listes de courses partagées. Travail en équipe.",
      tags: ["PHP", "Symfony"]
    }
  ]

  def index(conn, _params) do
    render(conn, :index,
      competences: @competences,
      page_title: "Compétences",
      projects: @projects
    )
  end

  def show(conn, %{"id" => id} = _params) do
    comp = Enum.find(@competences, fn comp -> id == comp.id end)
    render(conn, :show, competence: comp, page_title: comp.title)
  end
end
