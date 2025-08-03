# Projeto Mobile Gerenciamento De Medicamento

##  Aplicativos Avaliados

- **Medisafe**
- **WeMeds**
- **MyTherapy**
- **Tomar Remédio**

---

##  1. Medisafe

 Pontos Fortes:
- Interface amigável e intuitiva, com tela inicial em formato de calendário.
- Botões de atalho para adicionar medicamentos de forma rápida.
- Tela de atualizações com funcionalidades como consultas médicas e monitor de saúde.
- Tela dedicada para adição de medicamentos, com layout didático.
- Aba “Mais” com recursos como diário, reposição de medicamentos, configurações e personalização de tema (cor de fundo).

 Pontos Fracos:
- Algumas funcionalidades exigem conexão com a internet.
- Ausência de suporte ampliado a idiomas regionais.

---

##  2. WeMeds

 Pontos Fortes:
- Todas as funcionalidades funcionam offline.
- Abrangente: inclui receitas, prescrições, guias de atividade, verificação de vacinas e flashcards educativos.
- Funcionalidades com inteligência artificial para recomendações de saúde.

 Pontos Fracos:
- Interface desatualizada, com design menos moderno.
- Recursos avançados disponíveis apenas na versão paga.

---

##  3. MyTherapy

 Pontos Fortes:
- Interface moderna, com componentes acessíveis a usuários idosos.
- Funcionalidades completas: cadastro de medicamentos, médicos, sintomas, humor e atividades físicas.
- Sistema de notificações eficaz e gráfico de progresso de tratamento.

  Pontos Fracos:
- Não possui modo escuro ou opção de alterar o tema visual.
- Algumas funcionalidades exigem login com cadastro.

---

##  4. Tomar Remédio

 Pontos Fortes:
- Interface simples e funcional, ideal para usuários brasileiros.
- Cadastro de medicamentos fácil de usar.
- Dashboard com relatório de medicamentos tomados.

 Pontos Fracos:
- Algumas funcionalidades ainda estão em desenvolvimento.
- Falta de feedback visual para indicar em qual tela o usuário está.
- Ausência de recursos avançados como exportação de relatórios ou acompanhamento de sintomas.

---

##  Considerações Finais

Dentre os aplicativos avaliados, **Medisafe** e **MyTherapy** se destacam como os mais completos em termos de recursos e acompanhamento da rotina de saúde, sendo ideais para usuários que necessitam de controle rigoroso de medicamentos e consultas. Já o **WeMeds** oferece uma abordagem mais ampla e educativa da saúde, com diversas funcionalidades adicionais, embora sua interface e limitações na versão gratuita possam ser um obstáculo.

Por outro lado, o app **Tomar Remédio** se sobressai pela simplicidade e objetividade, sendo excelente para usuários que buscam um app prático, sem complexidade e totalmente em português. No entanto, ainda carece de melhorias na interface e em funcionalidades avançadas.

 ##  Proposta de Arquitetura do Software

Com base nas necessidades identificadas — como facilidade de uso, notificações de medicamentos, acessibilidade para idosos, funcionamento offline e possibilidade de expansão — propomos a seguinte arquitetura para o aplicativo de gerenciamento de medicamentos, e o app serve tanto para IOS quanto para Android:

###  Arquitetura Utilizada:  **

A arquitetura será baseada em **camadas independentes**, separando claramente as responsabilidades entre regras de negócio, interface, dados e serviços externos. Isso melhora a **manutenibilidade**, **testabilidade** e **escalabilidade** do projeto.

 ## Tecnologia Ultilizadas :
 -Flutter
 -SqlLite(Para o banco de dados)

 
