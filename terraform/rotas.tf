# Mapa servico -> porta do listener no NLB -> NodePort -> rotas do API Gateway (D6.6).
# Fonte unica para os listeners, target groups, regras de SG, integracoes e rotas de Billing e Execution
# (api-gateway.tf, security-groups.tf) e para a saida da auth-cpf ate o OS.
#
# Nenhuma rota /internal: o API Gateway publico nunca encaminha essas rotas (D6.4, D6.6).
locals {
  servicos_borda = {
    # OS: recursos criados antes desta etapa (listener :80, TG eks_nodes, rota ANY /v1/{proxy+}); ficam com os
    # enderecos atuais no state e aqui so o mapa os descreve. A rota generica perde para qualquer rota mais
    # especifica dos servicos abaixo.
    os = {
      porta_listener = 80
      node_port      = 30080
      rotas          = ["ANY /v1/{proxy+}"]
    }

    # Listener 8081 e 8082: acompanham o fim da NodePort (30081, 30082), sem colidir com o :80 do OS nem exigir
    # portas privilegiadas.
    billing = {
      porta_listener = 8081
      node_port      = 30081
      # O nome do target group tem limite de 32 caracteres; "<projeto>-<ambiente>-" ja ocupa 24.
      sufixo_target_group = "bill-tg"
      rotas = [
        "ANY /v1/orcamentos",
        "ANY /v1/orcamentos/{proxy+}",
        "ANY /v1/cobrancas",
        "ANY /v1/cobrancas/{proxy+}",
        "ANY /v1/pendencias-estorno",
        "ANY /v1/pendencias-estorno/{proxy+}",
        # Sem JWT: a protecao e a assinatura do Mercado Pago (D3.13).
        "POST /v1/webhooks/mercado-pago",
      ]
    }

    execution = {
      porta_listener      = 8082
      node_port           = 30082
      sufixo_target_group = "exec-tg"
      rotas = [
        "ANY /v1/tarefas",
        "ANY /v1/tarefas/{proxy+}",
      ]
    }
  }

  # Mesmo ASG do target group do OS: os nos sao os alvos de todos os listeners.
  asg_nos_eks = module.eks.eks_managed_node_groups["default"].node_group_autoscaling_group_names[0]

  servicos_borda_aditivos = {
    for nome, servico in local.servicos_borda : nome => servico if nome != "os"
  }

  rotas_aditivas = merge([
    for nome, servico in local.servicos_borda_aditivos : {
      for rota in servico.rotas : rota => nome
    }
  ]...)
}
