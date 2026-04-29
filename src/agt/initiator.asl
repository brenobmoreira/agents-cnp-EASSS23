!iniciar_leilao.

+!iniciar_leilao 
   <- .print("Preciso de alguem para pintar_parede");
      // Envia mensagem para todos agentes ativos
      .broadcast(tell, cfp(pintar_parede));

      .wait(2000);

      !escolher_vencedor(pintar_parede).

+propose(Servico, Preco)[source(Participante)] 
   <- .print("Recebi proposta do ", Participante, ": R$ ", Preco, " para o servico de ", Servico).

+!escolher_vencedor(Servico)
   <- .print("Tempo esgotado! Avaliando as propostas para ", Servico, "...");
      .findall(proposta(Preco, Agente), propose(Servico, Preco)[source(Agente)], ListaPropostas);
      .min(ListaPropostas, proposta(MenorPreco, Vencedor));
      .print("A proposta escolhida foi: ", Vencedor, " cobrando apenas R$ ", MenorPreco, "!");
      
      .send(Vencedor, tell, accept_proposal(Servico)).