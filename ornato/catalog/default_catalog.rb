# frozen_string_literal: true
# encoding: utf-8
#
# ORNATO — Plataforma Parametrica de Marcenaria Industrial
# catalog/default_catalog.rb — Catalogo padrao hardcoded
#
# Materiais, fitas e ferragens padrao para mercado brasileiro.
# Serve como base ate integracao com ERP.

module Ornato
  module Catalog
    module DefaultCatalog
      def self.materials
        [
          # MDF Branco TX
          { id: 'mdf_branco_tx_3', code: 'MDF_BR_TX_3', name: 'MDF Branco TX 3mm', type: 'mdf',
            thickness_nominal: 3, thickness_real: 3.0, width: 2750, height: 1850,
            color_group: 'branco_tx', grain: false, cost_m2: 15.0 },
          { id: 'mdf_branco_tx_6', code: 'MDF_BR_TX_6', name: 'MDF Branco TX 6mm', type: 'mdf',
            thickness_nominal: 6, thickness_real: 6.5, width: 2750, height: 1850,
            color_group: 'branco_tx', grain: false, cost_m2: 22.0 },
          { id: 'mdf_branco_tx_15', code: 'MDF_BR_TX_15', name: 'MDF Branco TX 15mm', type: 'mdf',
            thickness_nominal: 15, thickness_real: 15.5, width: 2750, height: 1850,
            color_group: 'branco_tx', grain: false, cost_m2: 55.0 },
          { id: 'mdf_branco_tx_18', code: 'MDF_BR_TX_18', name: 'MDF Branco TX 18mm', type: 'mdf',
            thickness_nominal: 18, thickness_real: 18.5, width: 2750, height: 1850,
            color_group: 'branco_tx', grain: false, cost_m2: 68.0 },
          { id: 'mdf_branco_tx_25', code: 'MDF_BR_TX_25', name: 'MDF Branco TX 25mm', type: 'mdf',
            thickness_nominal: 25, thickness_real: 25.5, width: 2750, height: 1850,
            color_group: 'branco_tx', grain: false, cost_m2: 95.0 },

          # MDF Carvalho
          { id: 'mdf_carvalho_15', code: 'MDF_CARV_15', name: 'MDF Carvalho 15mm', type: 'mdf',
            thickness_nominal: 15, thickness_real: 15.5, width: 2750, height: 1850,
            color_group: 'carvalho', grain: true, cost_m2: 75.0 },
          { id: 'mdf_carvalho_18', code: 'MDF_CARV_18', name: 'MDF Carvalho 18mm', type: 'mdf',
            thickness_nominal: 18, thickness_real: 18.5, width: 2750, height: 1850,
            color_group: 'carvalho', grain: true, cost_m2: 88.0 },

          # MDF Cinza
          { id: 'mdf_cinza_15', code: 'MDF_CZ_15', name: 'MDF Cinza Cristal 15mm', type: 'mdf',
            thickness_nominal: 15, thickness_real: 15.5, width: 2750, height: 1850,
            color_group: 'cinza', grain: false, cost_m2: 62.0 },
          { id: 'mdf_cinza_18', code: 'MDF_CZ_18', name: 'MDF Cinza Cristal 18mm', type: 'mdf',
            thickness_nominal: 18, thickness_real: 18.5, width: 2750, height: 1850,
            color_group: 'cinza', grain: false, cost_m2: 75.0 },

          # MDF Preto
          { id: 'mdf_preto_18', code: 'MDF_PT_18', name: 'MDF Preto TX 18mm', type: 'mdf',
            thickness_nominal: 18, thickness_real: 18.5, width: 2750, height: 1850,
            color_group: 'preto', grain: false, cost_m2: 78.0 },

          # MDF Nogueira
          { id: 'mdf_nogueira_15', code: 'MDF_NOG_15', name: 'MDF Nogueira 15mm', type: 'mdf',
            thickness_nominal: 15, thickness_real: 15.5, width: 2750, height: 1850,
            color_group: 'nogueira', grain: true, cost_m2: 72.0 },
          { id: 'mdf_nogueira_18', code: 'MDF_NOG_18', name: 'MDF Nogueira 18mm', type: 'mdf',
            thickness_nominal: 18, thickness_real: 18.5, width: 2750, height: 1850,
            color_group: 'nogueira', grain: true, cost_m2: 85.0 },

          # MDF Cru (sem revestimento)
          { id: 'mdf_cru_3', code: 'MDF_CRU_3', name: 'MDF Cru 3mm', type: 'mdf_cru',
            thickness_nominal: 3, thickness_real: 3.0, width: 2750, height: 1850,
            color_group: 'cru', grain: false, cost_m2: 8.0 },
          { id: 'mdf_cru_6', code: 'MDF_CRU_6', name: 'MDF Cru 6mm', type: 'mdf_cru',
            thickness_nominal: 6, thickness_real: 6.5, width: 2750, height: 1850,
            color_group: 'cru', grain: false, cost_m2: 12.0 },
          { id: 'mdf_cru_15', code: 'MDF_CRU_15', name: 'MDF Cru 15mm', type: 'mdf_cru',
            thickness_nominal: 15, thickness_real: 15.5, width: 2750, height: 1850,
            color_group: 'cru', grain: false, cost_m2: 35.0 },

          # Compensado
          { id: 'compensado_18', code: 'COMP_18', name: 'Compensado Naval 18mm', type: 'compensado',
            thickness_nominal: 18, thickness_real: 18.0, width: 2750, height: 1850,
            color_group: 'compensado', grain: true, cost_m2: 95.0 }
        ]
      end

      def self.edgebands
        [
          # Fitas PVC 22mm
          { id: 'fita_branco_tx_22x1', code: 'CMBOR22x010BRANCO_TX', name: 'Fita PVC Branco TX 22x1mm',
            width_mm: 22.0, thickness_mm: 1.0, color_group: 'branco_tx', finish: 'TX', cost_m: 1.20 },
          { id: 'fita_branco_tx_22x2', code: 'CMBOR22x020BRANCO_TX', name: 'Fita PVC Branco TX 22x2mm',
            width_mm: 22.0, thickness_mm: 2.0, color_group: 'branco_tx', finish: 'TX', cost_m: 2.50 },
          { id: 'fita_branco_tx_45x2', code: 'CMBOR45x020BRANCO_TX', name: 'Fita PVC Branco TX 45x2mm',
            width_mm: 45.0, thickness_mm: 2.0, color_group: 'branco_tx', finish: 'TX', cost_m: 4.00 },

          { id: 'fita_carvalho_22x1', code: 'CMBOR22x010CARVALHO', name: 'Fita PVC Carvalho 22x1mm',
            width_mm: 22.0, thickness_mm: 1.0, color_group: 'carvalho', finish: 'MAD', cost_m: 1.80 },
          { id: 'fita_carvalho_22x2', code: 'CMBOR22x020CARVALHO', name: 'Fita PVC Carvalho 22x2mm',
            width_mm: 22.0, thickness_mm: 2.0, color_group: 'carvalho', finish: 'MAD', cost_m: 3.20 },

          { id: 'fita_cinza_22x1', code: 'CMBOR22x010CINZA', name: 'Fita PVC Cinza Cristal 22x1mm',
            width_mm: 22.0, thickness_mm: 1.0, color_group: 'cinza', finish: 'TX', cost_m: 1.50 },
          { id: 'fita_cinza_22x2', code: 'CMBOR22x020CINZA', name: 'Fita PVC Cinza Cristal 22x2mm',
            width_mm: 22.0, thickness_mm: 2.0, color_group: 'cinza', finish: 'TX', cost_m: 2.80 },

          { id: 'fita_preto_22x1', code: 'CMBOR22x010PRETO', name: 'Fita PVC Preto TX 22x1mm',
            width_mm: 22.0, thickness_mm: 1.0, color_group: 'preto', finish: 'TX', cost_m: 1.50 },

          { id: 'fita_nogueira_22x1', code: 'CMBOR22x010NOGUEIRA', name: 'Fita PVC Nogueira 22x1mm',
            width_mm: 22.0, thickness_mm: 1.0, color_group: 'nogueira', finish: 'MAD', cost_m: 1.80 }
        ]
      end

      def self.hardware
        [
          # Dobradicas
          { id: 'dob_35mm_clip', code: 'FER_DOB_35', name: 'Dobradica Clip 35mm 110graus',
            type: 'dobradica', subtype: 'clip', bore_mm: 35.0, opening_angle: 110, cost: 8.50 },
          { id: 'dob_35mm_soft', code: 'FER_DOB_35S', name: 'Dobradica Clip 35mm Soft-Close',
            type: 'dobradica', subtype: 'soft_close', bore_mm: 35.0, opening_angle: 110, cost: 14.00 },

          # Corredicas
          { id: 'cor_telescopica_300', code: 'FER_COR_TEL_300', name: 'Corredica Telescopica 300mm',
            type: 'corredica', subtype: 'telescopica', length_mm: 300, deduction_mm: 25.4, cost: 18.00 },
          { id: 'cor_telescopica_350', code: 'FER_COR_TEL_350', name: 'Corredica Telescopica 350mm',
            type: 'corredica', subtype: 'telescopica', length_mm: 350, deduction_mm: 25.4, cost: 20.00 },
          { id: 'cor_telescopica_400', code: 'FER_COR_TEL_400', name: 'Corredica Telescopica 400mm',
            type: 'corredica', subtype: 'telescopica', length_mm: 400, deduction_mm: 25.4, cost: 22.00 },
          { id: 'cor_telescopica_450', code: 'FER_COR_TEL_450', name: 'Corredica Telescopica 450mm',
            type: 'corredica', subtype: 'telescopica', length_mm: 450, deduction_mm: 25.4, cost: 24.00 },
          { id: 'cor_telescopica_500', code: 'FER_COR_TEL_500', name: 'Corredica Telescopica 500mm',
            type: 'corredica', subtype: 'telescopica', length_mm: 500, deduction_mm: 25.4, cost: 26.00 },
          { id: 'cor_oculta_300', code: 'FER_COR_OCU_300', name: 'Corredica Oculta TANDEM 300mm',
            type: 'corredica', subtype: 'oculta', length_mm: 300, deduction_mm: 42.0, cost: 55.00 },
          { id: 'cor_oculta_450', code: 'FER_COR_OCU_450', name: 'Corredica Oculta TANDEM 450mm',
            type: 'corredica', subtype: 'oculta', length_mm: 450, deduction_mm: 42.0, cost: 65.00 },
          { id: 'cor_tandembox_500', code: 'FER_COR_TBX_500', name: 'Tandembox 500mm',
            type: 'corredica', subtype: 'tandembox', length_mm: 500, deduction_mm: 75.0, cost: 120.00 },

          # Suportes de prateleira
          { id: 'sup_prat_5mm', code: 'FER_SUP_5', name: 'Suporte de Prateleira 5mm',
            type: 'suporte', subtype: 'pino', diameter_mm: 5.0, cost: 0.30 },

          # Conectores
          { id: 'minifix_15mm', code: 'FER_MNF_15', name: 'Minifix 15mm',
            type: 'conector', subtype: 'minifix', bore_mm: 15.0, cost: 2.50 },
          { id: 'cavilha_8x30', code: 'FER_CAV_8', name: 'Cavilha 8x30mm',
            type: 'conector', subtype: 'cavilha', diameter_mm: 8.0, length_mm: 30, cost: 0.15 },

          # Puxadores
          { id: 'pux_96mm', code: 'FER_PUX_96', name: 'Puxador 96mm Entre-furos',
            type: 'puxador', subtype: 'barra', length_mm: 128, hole_spacing: 96, cost: 12.00 },
          { id: 'pux_128mm', code: 'FER_PUX_128', name: 'Puxador 128mm Entre-furos',
            type: 'puxador', subtype: 'barra', length_mm: 160, hole_spacing: 128, cost: 15.00 },
          { id: 'pux_160mm', code: 'FER_PUX_160', name: 'Puxador 160mm Entre-furos',
            type: 'puxador', subtype: 'barra', length_mm: 192, hole_spacing: 160, cost: 18.00 },
          { id: 'pux_cava', code: 'FER_PUX_CAV', name: 'Perfil Cava (por metro)',
            type: 'puxador', subtype: 'cava', cost_m: 35.00, cost: 35.00 },

          # Amortecedores
          { id: 'amort_porta', code: 'FER_AMR_POR', name: 'Amortecedor de Porta',
            type: 'amortecedor', subtype: 'porta', cost: 5.00 },
          { id: 'amort_basculante', code: 'FER_AMR_BAS', name: 'Pistao de Basculante',
            type: 'amortecedor', subtype: 'basculante', cost: 25.00 }
        ]
      end
    end
  end
end
