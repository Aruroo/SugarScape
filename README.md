# Modelo Sugarscape

Este proyecto es una extensión del modelo Sugarscape, propuesto originalmente por J. Epstein y R. Axtell en su libro *Growing Artificial Societies: Social Science from the Bottom Up* (1996). El modelo simula la desigualdad de la riqueza entre una población de agentes que recolectan recursos en un entorno distribuido espacialmente.

## Descripción General

En el modelo Sugarscape, la rejilla está compuesta por casillas (`patches`) que contienen una cantidad variable de azúcar, que representa la riqueza. Los agentes se mueven por la rejilla en busca de azúcar para sobrevivir, y la distribución de la riqueza resultante puede ser observada a lo largo del tiempo.

Como parte de las extensiones del modelo, se proponen métricas de la productividad y recaudación de impuestos, los cuales se utilizan para realizar una 
redistribución de la riqueza.

Se realizan diferentes análisis de los resultados utilizando Python.

## Características Principales

- **Rejilla de Patches**: Cada casilla contiene una cantidad de azúcar que crece con el tiempo hasta un máximo definido.
- **Agentes Inteligentes**: Los agentes se mueven hacia la casilla más rica dentro de su rango de visión, metabolizando azúcar con cada paso.
- **Dinámica de Población**: Los agentes mueren cuando se quedan sin azúcar o alcanzan su edad máxima. Nuevos agentes se generan para mantener una población constante.
- **Métricas de Desigualdad**: Se calculan indicadores como la curva de Lorenz y el índice de Gini para medir la desigualdad en la distribución de la riqueza.
- **Dinámicas de redistribución de la riqueza**: Se recaudan impuestos y se redistribuyen análogamente a la propuesta de la Renta Básica Universal.
- **Análisis de los resultados**: Se calculan medidas como el coeficiente de correlación y se grafican datos por medio de mapas de calor utilizando Python. 

## Parámetros Principales

- **Población Inicial**: Controlada por el deslizador `initial-population`.
- **Dotación Inicial de Azúcar**: Configurable mediante los deslizadores `minimum-sugar-endowment` y `maximum-sugar-endowment`.
- **Crecimiento de Azúcar**: El azúcar en cada casilla crece en una unidad con cada iteración.

## Instalación y Uso
Asegúrese de tener instalado [Netlogo](https://ccl.northwestern.edu/netlogo/download.shtml) en su versión 6.4.0-64
- Abre el archivo del modelo en NetLogo.
- Ajusta los parámetros según tus necesidades.
- Haz clic en el botón Setup para inicializar el modelo.
- Haz clic en Go para comenzar la simulación

Considérese que se tomó como base el modelo de Li, J. and Wilensky, U. (2009). NetLogo Sugarscape 3 Wealth Distribution model.
http://ccl.northwestern.edu/netlogo/models/Sugarscape3WealthDistribution. 
Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
