!start.

+!start
    <- .print("Iniciando múltiplos leilões em paralelo...");
    !!iniciar_leilao(pintar_parede);
    !!iniciar_leilao(instalar_luz);
    !!iniciar_leilao(trocar_piso).

+!iniciar_leilao(Servico) 
   <- .print("Preciso de ", Servico);
      // Envia mensagem para todos agentes ativos
      .broadcast(tell, cfp(Servico));

      .wait(2000);

      !escolher_vencedor(Servico).

+propose(Servico, Preco)[source(Participante)] 
   <- .print("Recebi proposta do ", Participante, ": R$ ", Preco, " para o servico de ", Servico).

+!escolher_vencedor(Servico)
   <- .print("Tempo esgotado! Avaliando as propostas para ", Servico, "...");
      .findall(proposta(Preco, Agente), propose(Servico, Preco)[source(Agente)], ListaPropostas);
      .min(ListaPropostas, proposta(MenorPreco, Vencedor));
      .print("A proposta escolhida foi: ", Vencedor, " cobrando apenas R$ ", MenorPreco, "!");
      
      .send(Vencedor, tell, accept_proposal(Servico)).